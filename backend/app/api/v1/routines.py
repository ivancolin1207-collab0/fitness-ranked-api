from __future__ import annotations

"""
Endpoints del Motor Cognitivo de Rutinas Dinámicas con Gemini 2.5 Flash (`/api/v1/routines`).
"""

from typing import Annotated, Any

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.entities import User
from app.services.ai_routine_service import (
    fetch_current_ai_routine_dict,
    generate_and_persist_ai_routine,
)

router = APIRouter(prefix="/routines", tags=["AI Dynamic Routines (Gemini 2.5 Flash)"])


@router.get("/current", status_code=status.HTTP_200_OK)
async def get_current_routine(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, Any]:
    """
    Devuelve la planificación dinámica actual de 5 días x 6 ejercicios del atleta (`user_routines`).
    Si aún no existe una rutina generada por IA para el usuario, retorna `{"has_routine": False}`.
    """
    return await fetch_current_ai_routine_dict(db, current_user)


@router.post("/generate-ai", status_code=status.HTTP_200_OK)
async def generate_ai_routine(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, Any]:
    """
    Llama a Gemini 2.5 Flash con la biometría real del atleta (Peso, % Grasa, LBM)
    y telemetría del wearable (Recuperación, Sueño, Estrés), genera una periodización
    de 5 días con 6 ejercicios exactos por día y cargas reales en KG, la almacena
    en PostgreSQL y reemplaza cualquier planificación anterior.
    """
    return await generate_and_persist_ai_routine(db, current_user)
