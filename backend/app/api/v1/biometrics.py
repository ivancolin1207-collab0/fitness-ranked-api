from __future__ import annotations

"""
Endpoints de Ingesta Biométrica Dual (`POST /biometrics` Manual + `POST /biometrics/scan` OCR Fitdays)
y Sincronización Real de Wearables (`/wearables/today`, `/wearables/sync`).
"""

from datetime import date
from typing import Annotated, Optional

from fastapi import APIRouter, Depends, File, Query, UploadFile, status
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import get_current_user, validate_uploaded_image
from app.models.entities import Biometric, User, WearableMetric
from app.schemas.biometrics import (
    BiometricRecordResponse,
    FitdaysExtractedMetrics,
    WearableSyncRequest,
    WearableSyncResponse,
)
from app.services.gemini_service import extract_fitdays_biometrics_from_image

router = APIRouter(tags=["Biometrics & Wearables"])


@router.post(
    "/biometrics",
    response_model=BiometricRecordResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_biometric_record(
    payload: FitdaysExtractedMetrics,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> BiometricRecordResponse:
    """
    Persiste en PostgreSQL un registro biométrico ingresado manualmente o confirmado
    tras el escaneo OCR de Fitdays, calculando automáticamente `lean_body_mass_kg`.
    """
    new_bio = Biometric(
        user_id=current_user.id,
        weight_kg=payload.weight_kg,
        fat_percentage=payload.fat_percentage,
        muscle_mass_kg=payload.muscle_mass_kg,
        skeletal_muscle_pct=payload.skeletal_muscle_pct,
        visceral_fat=payload.visceral_fat,
        body_water_pct=payload.body_water_pct,
        bmr=payload.bmr,
        ocr_confidence=payload.ocr_confidence,
        source_provider=payload.source_provider or "MANUAL_FORM",
    )
    db.add(new_bio)
    await db.commit()
    await db.refresh(new_bio)
    return BiometricRecordResponse.model_validate(new_bio)


@router.post(
    "/biometrics/scan",
    response_model=FitdaysExtractedMetrics,
    status_code=status.HTTP_200_OK,
)
async def scan_fitdays_biometrics(
    file: Annotated[UploadFile, File(description="Captura del reporte Fitdays (PNG/JPEG/WEBP)")],
    _current_user: Annotated[User, Depends(get_current_user)],
) -> FitdaysExtractedMetrics:
    """
    Procesa la captura de pantalla de Fitdays con Gemini 2.5 Flash Vision y devuelve
    los campos estructurados para autocompletar el formulario editable antes de guardar.
    """
    clean_bytes, clean_mime = await validate_uploaded_image(file)
    extracted = await extract_fitdays_biometrics_from_image(
        image_bytes=clean_bytes,
        mime_type=clean_mime,
    )
    return extracted


@router.get(
    "/biometrics/latest",
    response_model=Optional[BiometricRecordResponse],
    status_code=status.HTTP_200_OK,
)
async def get_latest_biometrics(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Optional[BiometricRecordResponse]:
    stmt = (
        select(Biometric)
        .where(Biometric.user_id == current_user.id)
        .order_by(Biometric.captured_at.desc())
        .limit(1)
    )
    record = (await db.execute(stmt)).scalar_one_or_none()
    if record is None:
        return None
    return BiometricRecordResponse.model_validate(record)


@router.get(
    "/biometrics/history",
    response_model=list[BiometricRecordResponse],
    status_code=status.HTTP_200_OK,
)
async def get_biometrics_history(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    limit: int = Query(default=12, ge=1, le=60),
) -> list[BiometricRecordResponse]:
    stmt = (
        select(Biometric)
        .where(Biometric.user_id == current_user.id)
        .order_by(Biometric.captured_at.asc())
        .limit(limit)
    )
    rows = (await db.execute(stmt)).scalars().all()
    return [BiometricRecordResponse.model_validate(r) for r in rows]


@router.get(
    "/wearables/today",
    response_model=Optional[WearableSyncResponse],
    status_code=status.HTTP_200_OK,
)
async def get_today_wearable_metrics(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Optional[WearableSyncResponse]:
    """
    Consulta si existe una sincronización real del wearable para el día actual en PostgreSQL.
    Si no existe, retorna `null` para que el cliente muestre 'Esperando sincronización de Whoop'.
    """
    today = date.today()
    stmt = (
        select(WearableMetric)
        .where(
            WearableMetric.user_id == current_user.id,
            WearableMetric.date == today,
        )
        .order_by(WearableMetric.synced_at.desc())
        .limit(1)
    )
    record = (await db.execute(stmt)).scalar_one_or_none()
    if record is None:
        return None
    return WearableSyncResponse.model_validate(record)


@router.post(
    "/wearables/sync",
    response_model=WearableSyncResponse,
    status_code=status.HTTP_200_OK,
)
async def sync_wearable_metrics(
    payload: WearableSyncRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> WearableSyncResponse:
    """
    Realiza un UPSERT transaccional de las métricas fisiológicas reales provenientes
    de WHOOP, Health Connect o Huawei GT y actualiza la fuente primaria del usuario.
    """
    current_user.preferred_wearable = payload.source_device

    stmt = (
        pg_insert(WearableMetric)
        .values(
            user_id=current_user.id,
            date=payload.date,
            strain_score=payload.strain_score,
            recovery_score=payload.recovery_score,
            hrv_ms=payload.hrv_ms,
            resting_hr=payload.resting_hr,
            avg_hr=payload.avg_hr,
            max_hr=payload.max_hr,
            sleep_hours=payload.sleep_hours,
            sleep_efficiency_pct=payload.sleep_efficiency_pct,
            source_device=payload.source_device,
        )
        .on_conflict_do_update(
            constraint="uq_user_date_device",
            set_={
                "strain_score": payload.strain_score,
                "recovery_score": payload.recovery_score,
                "hrv_ms": payload.hrv_ms,
                "resting_hr": payload.resting_hr,
                "avg_hr": payload.avg_hr,
                "max_hr": payload.max_hr,
                "sleep_hours": payload.sleep_hours,
                "sleep_efficiency_pct": payload.sleep_efficiency_pct,
            },
        )
        .returning(WearableMetric)
    )
    result = await db.execute(stmt)
    record = result.scalar_one()
    await db.commit()
    return WearableSyncResponse.model_validate(record)
