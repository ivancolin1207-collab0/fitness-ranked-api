from __future__ import annotations

"""
Endpoints de Ingesta Biométrica Dual (`POST /biometrics` Manual + `POST /biometrics/scan` OCR Fitdays)
y Sincronización Real de Wearables (`/wearables/today`, `/wearables/sync`).
"""

from datetime import date, datetime, timezone
from typing import Annotated, Any, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, File, Header, Query, UploadFile, status
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.elo_engine import WearableSource
from app.core.security import get_current_user, validate_uploaded_image
from app.models.entities import Biometric, RoutineTemplate, User, WearableMetric
from app.schemas.biometrics import (
    AiCoachChatRequest,
    AiCoachChatResponse,
    BiometricRecordResponse,
    FitdaysExtractedMetrics,
    HydrationAddRequest,
    HydrationLogEntrySchema,
    HydrationTodayResponse,
    WearableSyncRequest,
    WearableSyncResponse,
    WhoopScreenScanResponse,
)
from app.services.gemini_service import (
    extract_fitdays_biometrics_from_image,
    extract_whoop_screen_metrics,
    generate_coach_chat_reply,
)

router = APIRouter(tags=["Biometrics & Wearables"])

# Almacenamiento reactivo en memoria por (user_id, fecha) para logs de hidratación intradía
_HYDRATION_LOGS_STORE: dict[tuple[UUID, str], list[HydrationLogEntrySchema]] = {}


def get_user_today_hydration_ml(user_id: UUID) -> int:
    today_key = date.today().isoformat()
    entries = _HYDRATION_LOGS_STORE.get((user_id, today_key), [])
    return sum(e.amount_ml for e in entries)


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
    x_gemini_api_key: Annotated[Optional[str], Header()] = None,
) -> FitdaysExtractedMetrics:
    """
    Procesa la captura de pantalla de Fitdays con Gemini 2.5 Flash Vision y devuelve
    los campos estructurados para autocompletar el formulario editable antes de guardar.
    """
    clean_bytes, clean_mime = await validate_uploaded_image(file)
    extracted = await extract_fitdays_biometrics_from_image(
        image_bytes=clean_bytes,
        mime_type=clean_mime,
        fallback_api_key=x_gemini_api_key,
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


async def _compute_hydration_target_ml(
    db: AsyncSession, user_id: UUID
) -> int:
    latest_bio = (
        await db.execute(
            select(Biometric)
            .where(Biometric.user_id == user_id)
            .order_by(Biometric.captured_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()
    today_wearable = (
        await db.execute(
            select(WearableMetric)
            .where(
                WearableMetric.user_id == user_id,
                WearableMetric.date == date.today(),
            )
            .order_by(WearableMetric.synced_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()

    weight_kg = float(latest_bio.weight_kg) if latest_bio is not None else 78.0
    strain = float(today_wearable.strain_score) if today_wearable is not None else 9.6
    # Fórmula clínica deportiva: 35 ml/kg + 60 ml por punto de Strain
    target = int(round((weight_kg * 35.0 + strain * 60.0) / 50.0) * 50)
    return max(2200, min(5500, target))


@router.get(
    "/biometrics/hydration/today",
    response_model=HydrationTodayResponse,
    status_code=status.HTTP_200_OK,
)
async def get_today_hydration(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> HydrationTodayResponse:
    today_key = date.today().isoformat()
    entries = _HYDRATION_LOGS_STORE.get((current_user.id, today_key), [])
    total_ml = sum(e.amount_ml for e in entries)
    target_ml = await _compute_hydration_target_ml(db, current_user.id)
    progress = round(min(100.0, (total_ml / max(1, target_ml)) * 100.0), 1)
    return HydrationTodayResponse(
        date=today_key,
        total_ml=total_ml,
        target_ml=target_ml,
        progress_pct=progress,
        logs=entries,
    )


@router.post(
    "/biometrics/hydration",
    response_model=HydrationTodayResponse,
    status_code=status.HTTP_201_CREATED,
)
async def log_hydration_intake(
    payload: HydrationAddRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> HydrationTodayResponse:
    now = datetime.now(timezone.utc)
    today_key = date.today().isoformat()
    amount_str = (
        f"{payload.amount_ml / 1000.0:.1f} L"
        if payload.amount_ml >= 1000
        else f"{payload.amount_ml} ml"
    )
    time_str = payload.timestamp_label or now.strftime("%I:%M %p")
    label = f"{time_str}: {amount_str} consumido"

    entry = HydrationLogEntrySchema(
        amount_ml=payload.amount_ml,
        timestamp_label=label,
        recorded_at=now.isoformat(),
    )
    key = (current_user.id, today_key)
    current_list = list(_HYDRATION_LOGS_STORE.get(key, []))
    current_list.insert(0, entry)
    _HYDRATION_LOGS_STORE[key] = current_list

    total_ml = sum(e.amount_ml for e in current_list)
    target_ml = await _compute_hydration_target_ml(db, current_user.id)
    progress = round(min(100.0, (total_ml / max(1, target_ml)) * 100.0), 1)
    return HydrationTodayResponse(
        date=today_key,
        total_ml=total_ml,
        target_ml=target_ml,
        progress_pct=progress,
        logs=current_list,
    )


@router.post(
    "/wearables/scan-screen",
    response_model=WhoopScreenScanResponse,
    status_code=status.HTTP_200_OK,
)
async def scan_whoop_screen_metrics(
    file: Annotated[UploadFile, File(description="Captura de pantalla de la app WHOOP")],
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    x_gemini_api_key: Annotated[Optional[str], Header()] = None,
) -> WhoopScreenScanResponse:
    """
    Procesa una captura de pantalla de la app oficial de WHOOP mediante Gemini Vision
    (o análisis CV de anillos) y actualiza atómicamente la telemetría diaria del atleta.
    """
    clean_bytes, clean_mime = await validate_uploaded_image(file)
    extracted = await extract_whoop_screen_metrics(
        image_bytes=clean_bytes,
        mime_type=clean_mime,
        fallback_api_key=x_gemini_api_key,
    )

    today = date.today()
    sleep_hours_calc = round((extracted.sleep_performance_pct / 100.0) * 8.0, 2)
    avg_hr_calc = max(52, min(140, extracted.resting_hr + 12))
    max_hr_calc = max(avg_hr_calc + 25, 168)

    current_user.preferred_wearable = WearableSource.WHOOP

    stmt = (
        pg_insert(WearableMetric)
        .values(
            user_id=current_user.id,
            date=today,
            strain_score=extracted.strain_score,
            recovery_score=extracted.recovery_score,
            hrv_ms=extracted.hrv_ms,
            resting_hr=extracted.resting_hr,
            avg_hr=avg_hr_calc,
            max_hr=max_hr_calc,
            sleep_hours=sleep_hours_calc,
            sleep_efficiency_pct=extracted.sleep_performance_pct,
            source_device=WearableSource.WHOOP,
        )
        .on_conflict_do_update(
            constraint="uq_user_date_device",
            set_={
                "strain_score": extracted.strain_score,
                "recovery_score": extracted.recovery_score,
                "hrv_ms": extracted.hrv_ms,
                "resting_hr": extracted.resting_hr,
                "avg_hr": avg_hr_calc,
                "max_hr": max_hr_calc,
                "sleep_hours": sleep_hours_calc,
                "sleep_efficiency_pct": extracted.sleep_performance_pct,
            },
        )
        .returning(WearableMetric)
    )
    result = await db.execute(stmt)
    record = result.scalar_one()
    await db.commit()

    return WhoopScreenScanResponse(
        id=record.id,
        user_id=record.user_id,
        date=record.date,
        sleep_performance_pct=extracted.sleep_performance_pct,
        recovery_score=float(record.recovery_score),
        strain_score=float(record.strain_score),
        stress_level=extracted.stress_level,
        stress_category=extracted.stress_category,
        whoop_stress_level=extracted.stress_level,
        whoop_health_metrics_in_range=5,
        resting_hr=int(record.resting_hr or extracted.resting_hr),
        hrv_ms=float(record.hrv_ms or extracted.hrv_ms),
        avg_hr=int(record.avg_hr),
        max_hr=int(record.max_hr),
        sleep_hours=float(record.sleep_hours),
        sleep_efficiency_pct=float(
            record.sleep_efficiency_pct or extracted.sleep_performance_pct
        ),
        source_device=WearableSource.WHOOP,
        synced_at=record.synced_at,
    )


@router.post(
    "/ai/chat",
    response_model=AiCoachChatResponse,
    status_code=status.HTTP_200_OK,
)
async def chat_with_gemini_coach(
    payload: AiCoachChatRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    x_gemini_api_key: Annotated[Optional[str], Header()] = None,
) -> AiCoachChatResponse:
    """
    Endpoint interactivo para el panel flotante GEMINI COACH PERSONAL (`POST /api/v1/ai/chat`).
    Recibe el mensaje, historial y contexto biométrico en tiempo real del atleta.
    """
    today_wearable = (
        await db.execute(
            select(WearableMetric)
            .where(WearableMetric.user_id == current_user.id)
            .order_by(WearableMetric.date.desc(), WearableMetric.synced_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()

    latest_bio = (
        await db.execute(
            select(Biometric)
            .where(Biometric.user_id == current_user.id)
            .order_by(Biometric.captured_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()

    today_routine = (
        await db.execute(
            select(RoutineTemplate)
            .where(
                RoutineTemplate.user_id == current_user.id,
                RoutineTemplate.is_active.is_(True),
            )
            .order_by(RoutineTemplate.day_of_week.asc())
            .limit(1)
        )
    ).scalar_one_or_none()

    hyd_ml = get_user_today_hydration_ml(current_user.id)
    hyd_goal = await _compute_hydration_target_ml(db, current_user.id)

    client_ctx = payload.athlete_context or {}
    rec_val = float(
        client_ctx.get("recovery_score")
        or (today_wearable.recovery_score if today_wearable else 47.0)
    )
    sleep_pct_val = float(
        client_ctx.get("sleep_performance_pct")
        or (
            today_wearable.sleep_efficiency_pct
            if (today_wearable and today_wearable.sleep_efficiency_pct is not None)
            else 80.0
        )
    )
    strain_val = float(
        client_ctx.get("strain_score")
        or (today_wearable.strain_score if today_wearable else 7.1)
    )
    stress_lvl_val = float(
        client_ctx.get("stress_level")
        or (2.1 if rec_val < 50.0 else (1.5 if rec_val < 75.0 else 0.9))
    )
    stress_cat_val = str(
        client_ctx.get("stress_category")
        or ("Alto" if stress_lvl_val >= 2.0 else ("Medio" if stress_lvl_val >= 1.2 else "Bajo"))
    )

    merged_context: dict[str, Any] = {
        "athlete_name": current_user.full_name or current_user.username,
        "username": current_user.username,
        "training_goal": current_user.training_goal.value,
        "wearable_source": str(
            client_ctx.get("wearable_source")
            or (today_wearable.source_device.value if today_wearable else current_user.preferred_wearable.value)
        ),
        "recovery_score": rec_val,
        "sleep_performance_pct": sleep_pct_val,
        "strain_score": strain_val,
        "stress_level": stress_lvl_val,
        "stress_category": stress_cat_val,
        "hydration_ml": int(client_ctx.get("hydration_ml") or hyd_ml),
        "hydration_goal_ml": int(client_ctx.get("hydration_goal_ml") or hyd_goal),
        "weight_kg": float(latest_bio.weight_kg) if latest_bio else 78.0,
        "lean_body_mass_kg": float(latest_bio.lean_body_mass_kg) if latest_bio else 65.0,
        "routine_name": str(
            client_ctx.get("routine_name")
            or (today_routine.name if today_routine else "Rutina de Fuerza e Hipertrofia")
        ),
    }

    history_dicts = [
        {"role": item.role, "content": item.content} for item in payload.history
    ]

    reply, zone, suggestions = await generate_coach_chat_reply(
        message=payload.message,
        history=history_dicts,
        athlete_context=merged_context,
        fallback_api_key=x_gemini_api_key,
    )

    return AiCoachChatResponse(
        reply=reply,
        readiness_zone=zone,
        suggested_prompts=suggestions,
        generated_at=datetime.now(timezone.utc),
    )
