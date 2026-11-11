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

from app.api.v1 import auth, biometrics, leaderboard, routines, workouts
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
app.include_router(routines.router, prefix=settings.API_V1_STR)
app.include_router(workouts.router, prefix=settings.API_V1_STR)
app.include_router(leaderboard.router, prefix=settings.API_V1_STR)

app.include_router(auth.router, include_in_schema=False)
app.include_router(biometrics.router, include_in_schema=False)
app.include_router(routines.router, include_in_schema=False)
app.include_router(workouts.router, include_in_schema=False)
app.include_router(leaderboard.router, include_in_schema=False)


@app.on_event("startup")
async def ensure_postgres_enums() -> None:
    """
    Garantiza que wearable_source_enum incluya SAMSUNG_WATCH y APPLE_WATCH,
    crea las tablas `daily_readiness`, `user_routines`, `workout_days`, `workout_exercises`
    y elimina cualquier registro o plantilla estática histórica.
    """
    try:
        async with engine.execution_options(isolation_level="AUTOCOMMIT").connect() as conn:
            await conn.execute(
                text("ALTER TYPE wearable_source_enum ADD VALUE IF NOT EXISTS 'SAMSUNG_WATCH'")
            )
            await conn.execute(
                text("ALTER TYPE wearable_source_enum ADD VALUE IF NOT EXISTS 'APPLE_WATCH'")
            )
    except Exception as exc:
        logger.warning("Aviso en actualización de wearable_source_enum: %s", exc)

    try:
        async with engine.begin() as conn:
            await conn.execute(
                text(
                    "ALTER TABLE users ADD COLUMN IF NOT EXISTS weight_kg NUMERIC(5,2)"
                )
            )
            await conn.execute(
                text(
                    "ALTER TABLE users ADD COLUMN IF NOT EXISTS body_fat_pct NUMERIC(4,2)"
                )
            )
            await conn.execute(
                text(
                    """
                    CREATE TABLE IF NOT EXISTS daily_readiness (
                        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                        date DATE NOT NULL DEFAULT CURRENT_DATE,
                        sleep_pct NUMERIC(5,2) NOT NULL,
                        recovery_score NUMERIC(5,2) NOT NULL,
                        strain_score NUMERIC(4,1) NOT NULL,
                        stress_level NUMERIC(3,1) NOT NULL DEFAULT 0.0,
                        stress_category VARCHAR(20) NOT NULL DEFAULT 'SIN DATO',
                        sleep_hours NUMERIC(4,2) NOT NULL DEFAULT 0.0,
                        source_device VARCHAR(30) NOT NULL DEFAULT 'WHOOP',
                        synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        UNIQUE (user_id, date, source_device)
                    )
                    """
                )
            )
            await conn.execute(
                text(
                    "ALTER TABLE daily_readiness ADD COLUMN IF NOT EXISTS sleep_hours NUMERIC(4,2) NOT NULL DEFAULT 0.0"
                )
            )
            await conn.execute(
                text(
                    """
                    CREATE TABLE IF NOT EXISTS user_routines (
                        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                        name VARCHAR(180) NOT NULL,
                        weekly_focus VARCHAR(240) NOT NULL DEFAULT 'Enfoque biomecánico adaptado a LBM',
                        generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        status VARCHAR(30) NOT NULL DEFAULT 'active',
                        biometric_signature VARCHAR(80)
                    )
                    """
                )
            )
            await conn.execute(
                text(
                    "ALTER TABLE user_routines ADD COLUMN IF NOT EXISTS biometric_signature VARCHAR(80)"
                )
            )
            await conn.execute(
                text(
                    """
                    CREATE TABLE IF NOT EXISTS workout_days (
                        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                        routine_id UUID NOT NULL REFERENCES user_routines(id) ON DELETE CASCADE,
                        day_number INTEGER NOT NULL,
                        day_name VARCHAR(140) NOT NULL,
                        target_muscles VARCHAR(60)[] NOT NULL DEFAULT '{}'
                    )
                    """
                )
            )
            await conn.execute(
                text(
                    """
                    CREATE TABLE IF NOT EXISTS workout_exercises (
                        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                        day_id UUID NOT NULL REFERENCES workout_days(id) ON DELETE CASCADE,
                        "order" INTEGER NOT NULL,
                        exercise_key VARCHAR(80) NOT NULL DEFAULT 'bench_press_barbell',
                        name VARCHAR(140) NOT NULL,
                        muscle_group VARCHAR(80) NOT NULL,
                        sets INTEGER NOT NULL DEFAULT 4,
                        reps VARCHAR(30) NOT NULL DEFAULT '8-10',
                        prescribed_weight_kg NUMERIC(6,2) NOT NULL DEFAULT 40.0,
                        rpe NUMERIC(3,1) NOT NULL DEFAULT 8.0,
                        rest_seconds INTEGER NOT NULL DEFAULT 90,
                        tempo VARCHAR(30) NOT NULL DEFAULT '3-0-1-0',
                        coaching_cue TEXT NOT NULL DEFAULT 'Controla la fase excéntrica y mantén estabilidad escapular'
                    )
                    """
                )
            )
            # Eliminar plantillas estáticas antiguas (3 días) de usuarios sin rutina IA en user_routines
            await conn.execute(
                text(
                    """
                    DELETE FROM routine_templates
                    WHERE user_id NOT IN (SELECT user_id FROM user_routines WHERE status = 'active')
                    """
                )
            )
            # Limpiar filas mock residuales de versiones previas
            await conn.execute(
                text(
                    """
                    DELETE FROM wearable_metrics
                    WHERE ROUND(recovery_score) = 62 AND ROUND(sleep_efficiency_pct) = 90 AND resting_hr = 62
                    """
                )
            )
    except Exception as exc:
        logger.warning("No se pudo actualizar daily_readiness / user_routines en startup: %s", exc)


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
