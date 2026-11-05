from __future__ import annotations

"""
Punto de entrada principal de la aplicación FastAPI (`uvicorn app.main:app --reload`).
Integra los routers v1 (Auth, Biometrics/Wearables, Workouts y Leaderboard),
cabeceras de seguridad HTTP estrictas y manejadores de errores seguros.
"""

import logging
import traceback
from datetime import datetime, timezone

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app.api.v1 import auth, biometrics, leaderboard, workouts
from app.core.config import get_settings
from app.core.database import AsyncSessionLocal, engine

logger = logging.getLogger("apexmetrix_api")
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-7s | %(name)s | %(message)s",
)

settings = get_settings()

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS global habilitado para permitir consumo desde la APK móvil en cualquier red/IP
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def enforce_security_headers(request: Request, call_next):
    """Aplica cabeceras de endurecimiento HTTP en todas las respuestas."""
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Content-Security-Policy"] = (
        "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'"
    )
    response.headers["Permissions-Policy"] = (
        "camera=(), microphone=(), geolocation=(), payment=()"
    )
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Cache-Control"] = "no-store"
    return response


@app.exception_handler(SQLAlchemyError)
async def handle_database_errors(
    _request: Request, exc: SQLAlchemyError
) -> JSONResponse:
    """
    Registra el traceback completo de base de datos en los logs de Uvicorn.
    """
    traceback.print_exc()
    logger.exception("Error de base de datos interceptado: %s", exc)
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content={
            "detail": f"Error de base de datos: {str(exc)}"
        },
    )


# Registro de Routers v1 (/api/v1/*) y alias directos (/*) para compatibilidad total
app.include_router(auth.router, prefix=settings.API_V1_STR)
app.include_router(biometrics.router, prefix=settings.API_V1_STR)
app.include_router(workouts.router, prefix=settings.API_V1_STR)
app.include_router(leaderboard.router, prefix=settings.API_V1_STR)

app.include_router(auth.router, include_in_schema=False)
app.include_router(biometrics.router, include_in_schema=False)
app.include_router(workouts.router, include_in_schema=False)
app.include_router(leaderboard.router, include_in_schema=False)


@app.on_event("startup")
async def ensure_postgres_enums() -> None:
    """Garantiza que wearable_source_enum incluya SAMSUNG_WATCH y APPLE_WATCH en PostgreSQL."""
    try:
        async with engine.connect() as conn:
            autocommit_conn = await conn.execution_options(isolation_level="AUTOCOMMIT")
            await autocommit_conn.execute(
                text("ALTER TYPE wearable_source_enum ADD VALUE IF NOT EXISTS 'SAMSUNG_WATCH'")
            )
            await autocommit_conn.execute(
                text("ALTER TYPE wearable_source_enum ADD VALUE IF NOT EXISTS 'APPLE_WATCH'")
            )
    except Exception as exc:
        logger.warning("No se pudo actualizar wearable_source_enum en startup: %s", exc)


@app.get("/", tags=["Healthcheck"])
async def root_status() -> dict[str, str]:
    """Endpoint raíz informativo del servicio."""
    return {
        "status": "online",
        "service": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "health_endpoint": "/health",
        "api_prefix": settings.API_V1_STR,
    }


@app.get("/health", tags=["Healthcheck"])
def health() -> dict[str, str]:
    """Endpoint explícito de salud para Render Health Check."""
    return {"status": "ok"}


@app.get("/health/db", tags=["Healthcheck"])
async def healthcheck_db() -> dict[str, str]:
    """Verifica conectividad activa con PostgreSQL en Render."""
    async with AsyncSessionLocal() as session:
        await session.execute(text("SELECT 1"))
    return {
        "status": "healthy",
        "service": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


if __name__ == "__main__":
    import uvicorn

    # En entorno local de pruebas, enlazar estrictamente a 127.0.0.1
    uvicorn.run("app.main:app", host="127.0.0.1", port=8000, reload=True)
