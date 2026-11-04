from __future__ import annotations

"""
Motor asíncrono SQLAlchemy 2.0 y proveedor de sesiones (`get_db`) para Render PostgreSQL.
"""

import ssl
from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from app.core.config import get_settings


class Base(DeclarativeBase):
    """Clase base declarativa de SQLAlchemy 2.0."""


def _build_engine() -> AsyncEngine:
    settings = get_settings()
    db_url = settings.DATABASE_URL
    if not db_url:
        # URL local por defecto únicamente si no se definió en entorno (127.0.0.1)
        db_url = "postgresql+asyncpg://127.0.0.1:5432/fitness_db_evug"

    connect_args: dict[str, object] = {}
    if "render.com" in db_url:
        ssl_ctx = ssl.create_default_context()
        ssl_ctx.minimum_version = ssl.TLSVersion.TLSv1_2
        ssl_ctx.check_hostname = False
        ssl_ctx.verify_mode = ssl.CERT_NONE
        connect_args["ssl"] = ssl_ctx

    return create_async_engine(
        db_url,
        echo=False,
        pool_size=10,
        max_overflow=20,
        pool_pre_ping=True,
        connect_args=connect_args,
    )


engine: AsyncEngine = _build_engine()

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Dependencia FastAPI que inyecta una sesión transaccional asíncrona."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
