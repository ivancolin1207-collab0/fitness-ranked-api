from __future__ import annotations

"""
Configuración centralizada con `pydantic-settings`.
Soporta resolución multi-nivel de secretos y conversión automática de
DATABASE_URL al esquema asíncrono `postgresql+asyncpg://` requerido por SQLAlchemy 2.0.
"""

import hashlib
import logging
import os
import secrets
from functools import lru_cache
from pathlib import Path

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

logger = logging.getLogger(__name__)

ROOT_ENV_PATH = Path(__file__).resolve().parents[3] / ".env"
BACKEND_ENV_PATH = Path(__file__).resolve().parents[2] / ".env"


def _resolve_secret_key() -> str:
    """
    Resolución segura y persistente de SECRET_KEY:
    1. Variable de entorno explícita SECRET_KEY / JWT_SECRET_KEY.
    2. Derivación determinista desde DATABASE_URL en Render para que los tokens JWT
       nunca se invaliden tras reinicios de contenedores efímeros.
    3. Archivo local persistido para desarrollo.
    """
    env_key = os.getenv("SECRET_KEY") or os.getenv("JWT_SECRET_KEY")
    if env_key:
        return env_key
    db_url = os.getenv("DATABASE_URL", "").strip()
    if db_url:
        return hashlib.sha256(f"apexmetrix-jwt-key::{db_url}".encode("utf-8")).hexdigest()
    secret_file = BACKEND_ENV_PATH.parent / "jwt_secret.txt"
    if secret_file.exists():
        existing = secret_file.read_text(encoding="utf-8").strip()
        if existing:
            return existing
    generated = secrets.token_hex(32)
    try:
        secret_file.write_text(generated, encoding="utf-8")
    except OSError:
        logger.warning(
            "Generando SECRET_KEY criptográfica aislada por instancia."
        )
    return generated


class Settings(BaseSettings):
    PROJECT_NAME: str = "ApexMetrix Ranked Fitness API"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    ENVIRONMENT: str = "development"

    DATABASE_URL: str = ""
    GEMINI_API_KEY: str = ""
    SECRET_KEY: str = _resolve_secret_key()
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 365

    ALLOWED_ORIGINS: list[str] = [
        "https://apexmetrix-api.onrender.com",
        "http://127.0.0.1:8000",
        "http://localhost:8000",
    ]
    MAX_UPLOAD_SIZE_BYTES: int = 5 * 1024 * 1024  # 5 MB límite estricto para OCR
    DEFAULT_SEASON_ID: str = "2026-S4"

    model_config = SettingsConfigDict(
        env_file=(str(ROOT_ENV_PATH), str(BACKEND_ENV_PATH)),
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    @field_validator("DATABASE_URL", mode="before")
    @classmethod
    def assemble_asyncpg_url(cls, v: str) -> str:
        if not v:
            return ""
        url = v.strip()
        if url.startswith("postgres://"):
            return url.replace("postgres://", "postgresql+asyncpg://", 1)
        if url.startswith("postgresql://"):
            return url.replace("postgresql://", "postgresql+asyncpg://", 1)
        return url


@lru_cache
def get_settings() -> Settings:
    return Settings()
