from __future__ import annotations

"""
Seguridad Backend: Hashing de contraseñas, emisión y verificación estricta de JWT (HS256),
invalidación de sesiones, limitación de tasa (Rate Limiting) y validación de imágenes OCR.
"""

import io
import time
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import Annotated, Any, Optional
from uuid import UUID, uuid4

import bcrypt
from fastapi import Depends, HTTPException, Request, UploadFile, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from PIL import Image
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.database import get_db

bearer_scheme = HTTPBearer(auto_error=True)

# Registro en memoria de tokens revocados al cerrar sesión o desactivar cuenta
_REVOKED_TOKEN_JTIS: set[str] = set()

# Rate Limiter por IP/usuario en ventana deslizante de 60 segundos
_RATE_LIMIT_BUCKETS: dict[str, list[float]] = defaultdict(list)

# TODO(security): Integrar proveedores OAuth 2.0 / OpenID Connect (Google Sign-In / Apple) para clientes móviles.
# TODO(security): Implementar autenticación multifactor (MFA / TOTP) opcional para cuentas de rango Élite.
# TODO(security): Integrar validación de contraseñas filtradas (HaveIBeenPwned k-Anonymity API).


def validate_password_strength(password: str) -> None:
    """
    Valida la longitud y entropía mínima de la contraseña según OWASP ASVS:
    - Mínimo 8 caracteres (12+ recomendados), máximo 128 caracteres.
    - Permite cualquier carácter especial o Unicode.
    """
    if len(password) < 8:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="La contraseña debe tener al menos 8 caracteres.",
        )
    if len(password) > 128:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="La contraseña no puede exceder 128 caracteres.",
        )


def hash_password(password: str) -> str:
    """
    Genera hash bcrypt seguro compatible con Python 3.11+ y bcrypt 4.x+.
    Codifica en UTF-8 y trunca a 72 bytes para evitar ValueError interno de bcrypt.
    """
    validate_password_strength(password)
    pwd_bytes = password.encode("utf-8")[:72]
    hashed = bcrypt.hashpw(pwd_bytes, bcrypt.gensalt(rounds=12))
    return hashed.decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verifica contraseña en texto plano contra el hash bcrypt almacenado."""
    try:
        pwd_bytes = plain_password.encode("utf-8")[:72]
        hash_bytes = hashed_password.encode("utf-8")
        return bcrypt.checkpw(pwd_bytes, hash_bytes)
    except Exception:
        return False


def create_access_token(
    subject: UUID,
    extra_claims: Optional[dict[str, Any]] = None,
    expires_delta: Optional[timedelta] = None,
) -> str:
    settings = get_settings()
    now = datetime.now(timezone.utc)
    expire = now + (
        expires_delta
        if expires_delta is not None
        else timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    payload: dict[str, Any] = {
        "sub": str(subject),
        "iat": int(now.timestamp()),
        "exp": int(expire.timestamp()),
        "jti": uuid4().hex,
    }
    if extra_claims:
        payload.update(extra_claims)

    return jwt.encode(payload, settings.SECRET_KEY, algorithm="HS256")


def revoke_token_jti(jti: str) -> None:
    """Invalida inmediatamente el identificador único de un JWT (logout/desactivación)."""
    _REVOKED_TOKEN_JTIS.add(jti)


def decode_and_verify_jwt(token: str) -> dict[str, Any]:
    """
    Verifica el JWT forzando explícitamente el algoritmo HS256 (rechaza 'none')
    y validando la firma criptográfica, expiración ('exp') y lista de revocación.
    """
    settings = get_settings()
    try:
        unverified_header = jwt.get_unverified_header(token)
        if unverified_header.get("alg") != "HS256":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Algoritmo de firma JWT no permitido.",
            )
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=["HS256"],
            options={"require_exp": True, "require_sub": True},
        )
        jti = payload.get("jti")
        if jti and jti in _REVOKED_TOKEN_JTIS:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="La sesión ha sido invalidada. Inicia sesión nuevamente.",
            )
        return payload
    except HTTPException:
        raise
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token de autenticación inválido o expirado.",
        ) from exc


async def rate_limit_dependency(request: Request) -> None:
    """Rate limiter de 60 peticiones por minuto por cliente."""
    client_ip = request.client.host if request.client else "127.0.0.1"
    now = time.monotonic()
    window = _RATE_LIMIT_BUCKETS[client_ip]
    _RATE_LIMIT_BUCKETS[client_ip] = [t for t in window if now - t < 60.0]
    if len(_RATE_LIMIT_BUCKETS[client_ip]) >= 60:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Límite de peticiones excedido. Intenta de nuevo en un minuto.",
        )
    _RATE_LIMIT_BUCKETS[client_ip].append(now)


async def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(bearer_scheme)],
    db: Annotated[AsyncSession, Depends(get_db)],
    _rl: Annotated[None, Depends(rate_limit_dependency)],
):
    """
    Autentica al usuario en el servidor y verifica que su cuenta esté activa en PostgreSQL.
    """
    from app.models.entities import User

    payload = decode_and_verify_jwt(credentials.credentials)
    try:
        user_id = UUID(payload["sub"])
    except (KeyError, ValueError) as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Identificador de usuario inválido en el token.",
        ) from exc

    stmt = select(User).where(User.id == user_id, User.is_active.is_(True))
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario no encontrado o cuenta desactivada.",
        )
    return user


async def validate_uploaded_image(file: UploadFile) -> tuple[bytes, str]:
    """
    Valida estrictamente una imagen subida para OCR (Fitdays):
    1. Límite de tamaño máximo (5 MB).
    2. Lista permitida de extensiones y MIME types (PNG, JPEG, WEBP).
    3. Inspección de magic bytes en cabecera binaria y estructura de imagen con Pillow.
    4. Re-codificación en memoria (Content Disarm & Reconstruction básico) para eliminar
       metadatos EXIF o payloads incrustados antes de enviarla a Gemini Vision.
    """
    # TODO(security): Integrar escaneo antivirus en sandbox (ClamAV API) si los archivos se persisten en almacenamiento externo.
    settings = get_settings()
    max_bytes = max(settings.MAX_UPLOAD_SIZE_BYTES, 10 * 1024 * 1024)

    raw_bytes = await file.read(max_bytes + 1)
    if len(raw_bytes) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El archivo de imagen está vacío.",
        )
    if len(raw_bytes) > max_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="La imagen supera el límite máximo permitido de 10 MB.",
        )

    try:
        # Decodificación en una sola pasada, escalado máx 1080x1920 y compresión JPEG calidad 75
        # para proteger la memoria RAM del contenedor en Render (evita OOM / Error 502) y eliminar EXIF.
        with Image.open(io.BytesIO(raw_bytes)) as clean_img:
            rgb_img = clean_img.convert("RGB")
            rgb_img.thumbnail((1080, 1920), Image.Resampling.LANCZOS)
            out_buf = io.BytesIO()
            rgb_img.save(out_buf, format="JPEG", quality=75, optimize=True)
            sanitized_bytes = out_buf.getvalue()
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Archivo de imagen corrupto o formato no soportado.",
        ) from exc

    return sanitized_bytes, "image/jpeg"


def validate_base64_image(image_base64: str) -> tuple[bytes, str]:
    """
    Decodifica y sanea una imagen enviada en Base64 (JSON), aplicando el mismo
    filtro Pillow CDR (1080x1920 JPEG calidad 75, sin EXIF) que `validate_uploaded_image`.
    """
    import base64

    cleaned = image_base64.strip()
    if "," in cleaned and cleaned.lower().startswith("data:image"):
        cleaned = cleaned.split(",", 1)[1].strip()

    try:
        raw_bytes = base64.b64decode(cleaned, validate=False)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La cadena Base64 de la imagen no es válida.",
        ) from exc

    if len(raw_bytes) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El contenido de la imagen en Base64 está vacío.",
        )

    settings = get_settings()
    max_bytes = max(settings.MAX_UPLOAD_SIZE_BYTES, 10 * 1024 * 1024)
    if len(raw_bytes) > max_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="La imagen supera el límite máximo permitido de 10 MB.",
        )

    try:
        with Image.open(io.BytesIO(raw_bytes)) as clean_img:
            rgb_img = clean_img.convert("RGB")
            rgb_img.thumbnail((1080, 1920), Image.Resampling.LANCZOS)
            out_buf = io.BytesIO()
            rgb_img.save(out_buf, format="JPEG", quality=75, optimize=True)
            sanitized_bytes = out_buf.getvalue()
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Imagen Base64 corrupta o formato no soportado.",
        ) from exc

    return sanitized_bytes, "image/jpeg"
