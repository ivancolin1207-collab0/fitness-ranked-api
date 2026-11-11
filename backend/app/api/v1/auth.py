from __future__ import annotations

"""
Endpoints de Autenticación, Perfil Fisiológico y Onboarding (`/api/v1/auth`).
Unifica `users` y `biometrics` con sexo biológico, peso, estatura, % grasa corporal, LBM (Boer / real)
y regeneración automática de rutinas al cambiar la huella biométrica (`biometric_signature`).
"""

import logging
import traceback
from typing import Annotated, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy import delete, or_, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.database import get_db
from app.core.elo_engine import RankedTier
from app.core.security import (
    bearer_scheme,
    create_access_token,
    decode_and_verify_jwt,
    get_current_user,
    hash_password,
    rate_limit_dependency,
    revoke_token_jti,
    verify_password,
)
from app.models.entities import (
    Biometric,
    RankedPoint,
    RoutineTemplate,
    User,
)
from app.models.routine import UserRoutine
from app.schemas.auth import (
    PasswordResetDirectRequest,
    ProfileSetupUpdateRequest,
    TokenResponse,
    UserLoginRequest,
    UserProfileResponse,
    UserRegisterRequest,
    calculate_age_years,
    mask_email,
)
from app.services.biometrics_service import (
    derive_secondary_bioimpedance_metrics,
    get_athlete_biometrics,
    normalize_sex_code,
)

logger = logging.getLogger("apexmetrix_auth")

router = APIRouter(prefix="/auth", tags=["Authentication & Profile"])

_USER_BIO_COLUMNS_VERIFIED = False


async def _ensure_user_bio_columns(db: AsyncSession) -> None:
    global _USER_BIO_COLUMNS_VERIFIED
    if _USER_BIO_COLUMNS_VERIFIED:
        return
    try:
        async with db.begin_nested():
            await db.execute(
                text("ALTER TABLE users ADD COLUMN IF NOT EXISTS weight_kg NUMERIC(5,2)")
            )
            await db.execute(
                text(
                    "ALTER TABLE users ADD COLUMN IF NOT EXISTS body_fat_pct NUMERIC(4,2)"
                )
            )
        _USER_BIO_COLUMNS_VERIFIED = True
    except Exception:
        pass


async def _get_or_create_ranked_point(
    db: AsyncSession, user: User
) -> RankedPoint:
    settings = get_settings()
    stmt = select(RankedPoint).where(
        RankedPoint.user_id == user.id,
        RankedPoint.season_id == settings.DEFAULT_SEASON_ID,
    )
    rp = (await db.execute(stmt)).scalar_one_or_none()
    if rp is None:
        rp = RankedPoint(
            user_id=user.id,
            season_id=settings.DEFAULT_SEASON_ID,
            current_elo=1200,
            peak_elo=1200,
            tier=RankedTier.PLATA,
        )
        db.add(rp)
        await db.flush()
    return rp


async def _sync_biometric_record_from_profile(
    db: AsyncSession,
    user: User,
    weight_kg: Optional[float],
    body_fat_pct: Optional[float],
) -> None:
    """
    Si el usuario provee `weight_kg` (y opcionalmente `body_fat_pct`) durante el registro
    o en la pantalla de Perfil, sincroniza también un registro real en `biometrics`.
    """
    if weight_kg is None or weight_kg <= 0:
        return

    sex_norm = normalize_sex_code(user.biological_sex)
    height_val = float(user.height_cm) if user.height_cm is not None else None
    derived = derive_secondary_bioimpedance_metrics(
        sex=sex_norm,
        weight_kg=float(weight_kg),
        height_cm=height_val,
        body_fat_pct=float(body_fat_pct) if body_fat_pct is not None else None,
    )
    bio_row = Biometric(
        user_id=user.id,
        weight_kg=derived["weight_kg"],
        fat_percentage=derived["fat_percentage"],
        muscle_mass_kg=derived["muscle_mass_kg"],
        skeletal_muscle_pct=derived["skeletal_muscle_pct"],
        visceral_fat=derived["visceral_fat"],
        body_water_pct=derived["body_water_pct"],
        bmr=derived["bmr"],
        ocr_confidence=1.0,
        source_provider=derived["source_provider"],
    )
    db.add(bio_row)
    await db.flush()


async def _sync_routine_if_biometric_signature_changed(
    db: AsyncSession,
    user: User,
) -> None:
    """
    Verifica si el usuario ya tenía una rutina activa en `user_routines` cuya
    `biometric_signature` cambió tras editar sexo, peso, estatura o % grasa.
    Si cambió, regenera automáticamente su rutina y cargas en PostgreSQL.
    """
    try:
        from app.services.ai_routine_service import (
            ensure_ai_routine_tables,
            generate_and_persist_ai_routine,
        )

        await ensure_ai_routine_tables(db)
        active_routine = (
            await db.execute(
                select(UserRoutine)
                .where(
                    UserRoutine.user_id == user.id,
                    UserRoutine.status == "active",
                )
                .order_by(UserRoutine.generated_at.desc())
                .limit(1)
            )
        ).scalar_one_or_none()
        if active_routine is None:
            return

        bio = await get_athlete_biometrics(db, user.id)
        new_sig = bio.get("biometric_signature")
        if new_sig and active_routine.biometric_signature != new_sig:
            if bio.get("has_complete_biometrics"):
                await generate_and_persist_ai_routine(db, user)
            else:
                await db.execute(
                    delete(UserRoutine).where(UserRoutine.user_id == user.id)
                )
                await db.execute(
                    delete(RoutineTemplate).where(RoutineTemplate.user_id == user.id)
                )
                await db.flush()
    except Exception as exc:
        logger.warning(
            "No se pudo regenerar rutina automáticamente tras actualizar perfil: %s",
            exc,
        )


async def _to_user_profile_async(
    db: AsyncSession,
    user: User,
    ranked: Optional[RankedPoint] = None,
) -> UserProfileResponse:
    elo = int(ranked.current_elo) if ranked is not None else 1200
    tier_val = (
        ranked.tier.value
        if (ranked is not None and isinstance(ranked.tier, RankedTier))
        else (str(ranked.tier) if ranked is not None else "Plata")
    )
    bio = await get_athlete_biometrics(db, user.id)
    return UserProfileResponse(
        id=user.id,
        username=user.username,
        full_name=user.full_name,
        masked_email=mask_email(user.email),
        birth_date=user.birth_date,
        age_years=calculate_age_years(user.birth_date),
        biological_sex=user.biological_sex,
        sex=bio["sex"],
        height_cm=bio["height_cm"],
        weight_kg=bio["weight_kg"],
        body_fat_pct=bio["body_fat_pct"],
        lbm_kg=bio["lbm_kg"],
        biometric_signature=bio["biometric_signature"],
        training_goal=user.training_goal,
        preferred_wearable=user.preferred_wearable,
        unit_system=user.unit_system,
        onboarding_completed=bool(user.onboarding_completed),
        current_elo=elo,
        current_tier=tier_val,
        is_active=user.is_active,
        created_at=user.created_at,
    )


@router.post(
    "/register",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
)
async def register_user(
    payload: UserRegisterRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    _rl: Annotated[None, Depends(rate_limit_dependency)],
) -> TokenResponse:
    """
    Registra un nuevo usuario en PostgreSQL de forma transaccional,
    guardando sexo biológico (`male`/`female`), peso corporal, estatura y % grasa (si se indican),
    e inicializa atómicamente `ranked_points` (1200 ELO - Plata).
    """
    try:
        await _ensure_user_bio_columns(db)
        settings = get_settings()
        clean_username = payload.username.strip()
        clean_email = payload.email.lower().strip()

        existing_stmt = select(User).where(
            or_(User.username == clean_username, User.email == clean_email)
        )
        existing_user = (await db.execute(existing_stmt)).scalar_one_or_none()
        if existing_user is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="El nombre de usuario o correo electrónico ya está registrado.",
            )

        onboarding_done = bool(
            payload.height_cm is not None and payload.weight_kg is not None
        )
        new_user = User(
            username=clean_username,
            email=clean_email,
            password_hash=hash_password(payload.password),
            full_name=payload.full_name.strip() if payload.full_name else None,
            birth_date=payload.birth_date,
            biological_sex=payload.biological_sex,
            height_cm=payload.height_cm,
            weight_kg=payload.weight_kg,
            body_fat_pct=payload.body_fat_pct,
            training_goal=payload.training_goal,
            preferred_wearable=payload.preferred_wearable,
            unit_system=payload.unit_system,
            onboarding_completed=onboarding_done,
        )
        db.add(new_user)
        await db.flush()

        await _sync_biometric_record_from_profile(
            db=db,
            user=new_user,
            weight_kg=payload.weight_kg,
            body_fat_pct=payload.body_fat_pct,
        )

        season_id = settings.DEFAULT_SEASON_ID or "2026-S4"
        ranked = RankedPoint(
            user_id=new_user.id,
            season_id=season_id,
            current_elo=1200,
            peak_elo=1200,
            tier=RankedTier.PLATA,
        )
        db.add(ranked)
        await db.flush()

        await db.commit()
        await db.refresh(new_user)

        profile_resp = await _to_user_profile_async(db, new_user, ranked)
        token = create_access_token(
            subject=new_user.id,
            extra_claims={
                "unit_system": new_user.unit_system.value,
                "sex": new_user.biological_sex.value,
            },
        )
        return TokenResponse(
            access_token=token,
            expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            user=profile_resp,
        )
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        traceback.print_exc()
        logger.exception("Error durante el registro de usuario (%s): %s", payload.username, e)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error al registrar usuario: {str(e)}",
        ) from e


@router.post(
    "/login",
    response_model=TokenResponse,
    status_code=status.HTTP_200_OK,
)
async def login_user(
    payload: UserLoginRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    _rl: Annotated[None, Depends(rate_limit_dependency)],
) -> TokenResponse:
    try:
        await _ensure_user_bio_columns(db)
        settings = get_settings()
        identifier = payload.username_or_email.strip()
        stmt = select(User).where(
            or_(User.username == identifier, User.email == identifier.lower()),
            User.is_active.is_(True),
        )
        user = (await db.execute(stmt)).scalar_one_or_none()
        if user is None or not verify_password(payload.password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Credenciales inválidas.",
            )

        ranked = await _get_or_create_ranked_point(db, user)
        await db.commit()

        profile_resp = await _to_user_profile_async(db, user, ranked)
        token = create_access_token(
            subject=user.id,
            extra_claims={
                "unit_system": user.unit_system.value,
                "sex": user.biological_sex.value,
            },
        )
        return TokenResponse(
            access_token=token,
            expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            user=profile_resp,
        )
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        traceback.print_exc()
        logger.exception("Error en login_user: %s", e)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error al iniciar sesión: {str(e)}",
        ) from e


@router.put(
    "/profile",
    response_model=UserProfileResponse,
    status_code=status.HTTP_200_OK,
)
@router.post(
    "/profile",
    response_model=UserProfileResponse,
    status_code=status.HTTP_200_OK,
)
async def update_user_profile(
    payload: ProfileSetupUpdateRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> UserProfileResponse:
    """
    Actualiza el perfil fisiológico (sexo biológico, peso, estatura, % grasa) en Render PostgreSQL,
    sincroniza `biometrics` y regenera automáticamente la rutina IA si cambió `biometric_signature`.
    """
    try:
        await _ensure_user_bio_columns(db)
        if payload.username and payload.username.strip() != current_user.username:
            new_uname = payload.username.strip()
            taken = (
                await db.execute(
                    select(User.id).where(
                        User.username == new_uname,
                        User.id != current_user.id,
                    )
                )
            ).scalar_one_or_none()
            if taken is not None:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Ese username ya está en uso por otro atleta.",
                )
            current_user.username = new_uname

        current_user.full_name = payload.full_name.strip()
        if payload.birth_date is not None:
            current_user.birth_date = payload.birth_date
        current_user.biological_sex = payload.biological_sex
        current_user.height_cm = payload.height_cm
        if payload.weight_kg is not None:
            current_user.weight_kg = payload.weight_kg
        if payload.body_fat_pct is not None:
            current_user.body_fat_pct = payload.body_fat_pct
        current_user.training_goal = payload.training_goal
        current_user.preferred_wearable = payload.preferred_wearable
        current_user.unit_system = payload.unit_system
        current_user.onboarding_completed = True
        await db.flush()

        if payload.weight_kg is not None:
            await _sync_biometric_record_from_profile(
                db=db,
                user=current_user,
                weight_kg=payload.weight_kg,
                body_fat_pct=payload.body_fat_pct,
            )

        ranked = await _get_or_create_ranked_point(db, current_user)
        await db.commit()
        await db.refresh(current_user)

        await _sync_routine_if_biometric_signature_changed(db, current_user)

        return await _to_user_profile_async(db, current_user, ranked)
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        traceback.print_exc()
        logger.exception("Error actualizando perfil: %s", e)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error al actualizar perfil: {str(e)}",
        ) from e


@router.post("/logout", status_code=status.HTTP_200_OK)
async def logout_user(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(bearer_scheme)],
    _current_user: Annotated[User, Depends(get_current_user)],
) -> dict[str, str]:
    claims = decode_and_verify_jwt(credentials.credentials)
    jti = claims.get("jti")
    if jti:
        revoke_token_jti(str(jti))
    return {"status": "logged_out"}


@router.get("/me", response_model=UserProfileResponse, status_code=status.HTTP_200_OK)
async def get_my_profile(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> UserProfileResponse:
    await _ensure_user_bio_columns(db)
    ranked = await _get_or_create_ranked_point(db, current_user)
    await db.commit()
    return await _to_user_profile_async(db, current_user, ranked)


@router.post(
    "/reset-password",
    response_model=TokenResponse,
    status_code=status.HTTP_200_OK,
)
@router.post(
    "/forgot-password-direct",
    response_model=TokenResponse,
    status_code=status.HTTP_200_OK,
)
async def reset_password_direct(
    payload: PasswordResetDirectRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    _rl: Annotated[None, Depends(rate_limit_dependency)],
) -> TokenResponse:
    """
    Permite restablecer la contraseña ingresando el correo electrónico (o username)
    del atleta registrado en PostgreSQL y emite un nuevo JWT persistente.
    """
    try:
        await _ensure_user_bio_columns(db)
        settings = get_settings()
        identifier = payload.email.strip()
        stmt = select(User).where(
            or_(
                User.email == identifier.lower(),
                User.username == identifier,
            ),
            User.is_active.is_(True),
        )
        user = (await db.execute(stmt)).scalar_one_or_none()
        if user is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No se encontró ninguna cuenta activa con ese correo electrónico o username.",
            )

        user.password_hash = hash_password(payload.new_password)
        ranked = await _get_or_create_ranked_point(db, user)
        await db.commit()
        await db.refresh(user)

        profile_resp = await _to_user_profile_async(db, user, ranked)
        token = create_access_token(
            subject=user.id,
            extra_claims={
                "unit_system": user.unit_system.value,
                "sex": user.biological_sex.value,
            },
        )
        return TokenResponse(
            access_token=token,
            expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            user=profile_resp,
        )
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        traceback.print_exc()
        logger.exception("Error en reset_password_direct: %s", e)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"No se pudo restablecer la contraseña: {str(e)}",
        ) from e
