from __future__ import annotations

"""
Endpoints del Motor Cognitivo de Rutinas Dinámicas con Gemini 2.5 Flash (`/api/v1/routines`).
"""

import traceback
from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException, status
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
    Consulta la rutina activa del usuario en PostgreSQL (`user_routines`).
    Si cambió su `biometric_signature` (peso, Fitdays o sexo biológico), la regenera automáticamente.
    """
    try:
        current = await fetch_current_ai_routine_dict(db, current_user)
        return {
            "status": "success",
            "routine": current if current.get("has_routine") else None,
            **current,
        }
    except HTTPException:
        raise
    except Exception as exc:
        print("ERROR DETALLADO EN GET_CURRENT_ROUTINE:", traceback.format_exc())
        await db.rollback()
        raise HTTPException(
            status_code=500, detail=f"Fallo al consultar rutina: {str(exc)}"
        ) from exc


@router.post("/generate-ai", status_code=status.HTTP_200_OK)
async def generate_ai_routine(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, Any]:
    """
    Genera y persiste en PostgreSQL una periodización de 5 días × 6 ejercicios exactos por día
    con cargas calculadas matemáticamente a partir de `sex`, `weight_kg`, `lbm_kg` y `recovery_score` real.
    """
    try:
        return await generate_and_persist_ai_routine(db, current_user)
    except HTTPException:
        raise
    except Exception as exc:
        print("ERROR DETALLADO EN GENERATE_AI:", traceback.format_exc())
        await db.rollback()
        raise HTTPException(
            status_code=500, detail=f"Fallo al generar rutina: {str(exc)}"
        ) from exc
