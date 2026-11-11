from __future__ import annotations

"""
Endpoints de Ingesta Biométrica Dual (`POST /biometrics` Manual + `POST /biometrics/scan` OCR Fitdays)
y Sincronización Real de Wearables (`/wearables/today`, `/wearables/sync`, `/wearables/scan-whoop`, `/wearables/scan-screen`).
CERO MOCKS / CERO CONSTANTES ESTÁTICAS.
"""

import logging
from datetime import date, datetime, timezone
from typing import Annotated, Any, Optional
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, File, Form, Header, HTTPException, Query, UploadFile, status
from sqlalchemy import delete, func, select, text
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.elo_engine import WearableSource
from app.core.security import get_current_user, validate_uploaded_image
from app.models.entities import Biometric, RoutineTemplate, User, WearableMetric
from app.models.routine import UserRoutine
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
from app.services.biometrics_service import (
    derive_secondary_bioimpedance_metrics,
    get_athlete_biometrics,
    get_today_athlete_readiness,
    normalize_sex_code,
)
from app.services.gemini_service import (
    extract_fitdays_biometrics_from_image,
    generate_coach_chat_reply,
    scan_wearable_screen,
)

logger = logging.getLogger("apexmetrix_biometrics")
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
    tras el escaneo OCR de Fitdays, sincroniza `users` (`weight_kg`, `body_fat_pct`),
    y regenera automáticamente la rutina IA si cambió `biometric_signature`.
    """
    sex_norm = normalize_sex_code(current_user.biological_sex)
    height_val = (
        float(current_user.height_cm) if current_user.height_cm is not None else None
    )
    derived = derive_secondary_bioimpedance_metrics(
        sex=sex_norm,
        weight_kg=payload.weight_kg,
        height_cm=height_val,
        body_fat_pct=payload.fat_percentage,
    )

    new_bio = Biometric(
        user_id=current_user.id,
        weight_kg=payload.weight_kg,
        fat_percentage=payload.fat_percentage,
        muscle_mass_kg=payload.muscle_mass_kg
        if payload.muscle_mass_kg is not None
        else derived["muscle_mass_kg"],
        skeletal_muscle_pct=payload.skeletal_muscle_pct
        if payload.skeletal_muscle_pct is not None
        else derived["skeletal_muscle_pct"],
        visceral_fat=max(
            1,
            min(
                60,
                int(
                    round(
                        float(
                            payload.visceral_fat
                            if payload.visceral_fat is not None
                            else derived["visceral_fat"]
                        )
                    )
                ),
            ),
        ),
        body_water_pct=payload.body_water_pct
        if payload.body_water_pct is not None
        else derived["body_water_pct"],
        bmr=payload.bmr if payload.bmr is not None else derived["bmr"],
        ocr_confidence=payload.ocr_confidence,
        source_provider=payload.source_provider or "MANUAL_FORM",
    )
    db.add(new_bio)

    # Sincronizar columnas de referencia directa en `users`
    try:
        current_user.weight_kg = payload.weight_kg
        current_user.body_fat_pct = payload.fat_percentage
    except Exception:
        pass

    await db.commit()
    await db.refresh(new_bio)

    # Si existe rutina activa cuya huella biométrica cambió, regenerar automáticamente
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
                    UserRoutine.user_id == current_user.id,
                    UserRoutine.status == "active",
                )
                .order_by(UserRoutine.generated_at.desc())
                .limit(1)
            )
        ).scalar_one_or_none()
        if active_routine is not None:
            bio_state = await get_athlete_biometrics(db, current_user.id)
            new_sig = bio_state.get("biometric_signature")
            if new_sig and active_routine.biometric_signature != new_sig:
                await generate_and_persist_ai_routine(db, current_user)
    except Exception as exc:
        logger.warning(
            "Aviso al sincronizar rutina tras nuevo registro biométrico: %s", exc
        )

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
    try:
        clean_bytes, clean_mime = await validate_uploaded_image(file)
        extracted = await extract_fitdays_biometrics_from_image(
            image_bytes=clean_bytes,
            mime_type=clean_mime,
            fallback_api_key=x_gemini_api_key,
        )
        return extracted
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


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
    Consulta si existe una sincronización real del wearable para el día actual (`date.today()`)
    en PostgreSQL (`daily_readiness` + `wearable_metrics`).
    Si el usuario aún NO ha escaneado ni sincronizado su banda hoy, retorna `null` (`--` en UI).
    """
    today = date.today()
    wm_record = (
        await db.execute(
            select(WearableMetric)
            .where(
                WearableMetric.user_id == current_user.id,
                WearableMetric.date == today,
            )
            .order_by(WearableMetric.synced_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()

    readiness = await get_today_athlete_readiness(db, current_user.id)
    if not readiness["has_readiness_today"] and wm_record is None:
        return None

    raw_dev = str(
        readiness.get("source_device")
        or (wm_record.source_device.value if wm_record is not None else "WHOOP")
    ).upper()
    if "HUAWEI" in raw_dev:
        source_enum = WearableSource.HUAWEI_GT
    elif "SAMSUNG" in raw_dev:
        source_enum = WearableSource.SAMSUNG_WATCH
    elif "APPLE" in raw_dev:
        source_enum = WearableSource.APPLE_WATCH
    elif "HEALTH" in raw_dev:
        source_enum = WearableSource.HEALTH_CONNECT
    else:
        source_enum = WearableSource.WHOOP

    sleep_pct_val = readiness.get("sleep_pct")
    rec_val = float(
        readiness.get("recovery_score")
        if readiness.get("recovery_score") is not None
        else (wm_record.recovery_score if wm_record is not None else 0.0)
    )
    strain_val = float(
        readiness.get("strain_score")
        if readiness.get("strain_score") is not None
        else (wm_record.strain_score if wm_record is not None else 0.0)
    )
    sleep_h_val = float(
        readiness.get("sleep_hours")
        if readiness.get("sleep_hours") is not None
        else (wm_record.sleep_hours if wm_record is not None else 0.0)
    )
    stress_lvl = readiness.get("stress_level")
    stress_cat = readiness.get("stress_category")

    return WearableSyncResponse(
        id=wm_record.id if wm_record is not None else uuid4(),
        user_id=current_user.id,
        date=today,
        strain_score=strain_val,
        recovery_score=rec_val,
        hrv_ms=readiness.get("hrv_ms"),
        resting_hr=readiness.get("resting_hr"),
        avg_hr=int(wm_record.avg_hr) if wm_record is not None else 0,
        max_hr=int(wm_record.max_hr) if wm_record is not None else 0,
        sleep_hours=sleep_h_val,
        sleep_efficiency_pct=sleep_pct_val,
        sleep_pct=sleep_pct_val,
        stress_level=stress_lvl,
        stress_category=stress_cat,
        whoop_stress_level=stress_lvl,
        source_device=source_enum,
        synced_at=wm_record.synced_at
        if wm_record is not None
        else datetime.now(timezone.utc),
    )


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
    de Health Connect o ingreso manual y actualiza la fuente primaria del usuario.
    """
    current_user.preferred_wearable = payload.source_device

    await db.execute(
        delete(WearableMetric).where(
            WearableMetric.user_id == current_user.id,
            WearableMetric.date == payload.date,
        )
    )
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
                "synced_at": func.now(),
            },
        )
        .returning(WearableMetric)
    )
    result = await db.execute(stmt)
    record = result.scalar_one()

    # Sincronizar también en `daily_readiness` para que toda consulta lea el último estado unificado
    try:
        async with db.begin_nested():
            await db.execute(
                text(
                    "DELETE FROM daily_readiness WHERE user_id = :uid AND date = :dt"
                ),
                {"uid": current_user.id, "dt": payload.date},
            )
            await db.execute(
                text(
                    """
                    INSERT INTO daily_readiness (
                        user_id, date, sleep_pct, recovery_score, strain_score,
                        stress_level, stress_category, sleep_hours, source_device, synced_at
                    )
                    VALUES (
                        :uid, :dt, :sleep_pct, :rec, :strain,
                        0.0, 'SIN DATO', :sleep_h, :src, NOW()
                    )
                    """
                ),
                {
                    "uid": current_user.id,
                    "dt": payload.date,
                    "sleep_pct": float(payload.sleep_efficiency_pct or 0.0),
                    "rec": payload.recovery_score,
                    "strain": payload.strain_score,
                    "sleep_h": payload.sleep_hours,
                    "src": payload.source_device.value,
                },
            )
    except Exception:
        pass

    await db.commit()
    await db.refresh(record)
    resp = WearableSyncResponse.model_validate(record)
    resp.sleep_pct = payload.sleep_efficiency_pct
    return resp


async def _compute_hydration_target_ml(
    db: AsyncSession, user_id: UUID
) -> int:
    bio = await get_athlete_biometrics(db, user_id)
    readiness = await get_today_athlete_readiness(db, user_id)

    weight_kg = bio.get("weight_kg")
    strain = float(readiness.get("strain_score") or 0.0)
    if weight_kg is None or weight_kg <= 0:
        return 2500
    target = int(round((float(weight_kg) * 35.0 + strain * 60.0) / 50.0) * 50)
    return max(1800, min(5500, target))


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
    "/wearables/scan-whoop",
    response_model=WhoopScreenScanResponse,
    status_code=status.HTTP_200_OK,
)
@router.post(
    "/wearables/scan-screen",
    response_model=WhoopScreenScanResponse,
    status_code=status.HTTP_200_OK,
)
async def scan_whoop_screen_metrics(
    file: Annotated[UploadFile, File(description="Captura comprimida del wearable (WHOOP, HUAWEI, SAMSUNG, APPLE)")],
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    source_device: Annotated[Optional[str], Form()] = None,
    source_wearable: Annotated[Optional[str], Form()] = None,
    x_gemini_api_key: Annotated[Optional[str], Header()] = None,
) -> WhoopScreenScanResponse:
    """
    Procesa una captura de pantalla de wearable mediante Gemini 2.5 Flash Vision
    (idéntico a Fitdays) y realiza un UPSERT real en PostgreSQL filtrando por `user_id` y `today`
    (`db.commit()` + `db.refresh()`), sobrescribiendo cualquier lectura previa del mismo día.
    """
    raw_source = (
        source_device
        or source_wearable
        or (current_user.preferred_wearable.value if current_user.preferred_wearable else "WHOOP")
    ).upper().strip()

    if "HUAWEI" in raw_source:
        resolved_source = WearableSource.HUAWEI_GT
    elif "SAMSUNG" in raw_source:
        resolved_source = WearableSource.SAMSUNG_WATCH
    elif "APPLE" in raw_source:
        resolved_source = WearableSource.APPLE_WATCH
    else:
        resolved_source = WearableSource.WHOOP

    try:
        clean_bytes, clean_mime = await validate_uploaded_image(file)
        extracted = await scan_wearable_screen(
            image_bytes=clean_bytes,
            source_wearable=resolved_source.value,
            mime_type=clean_mime,
            fallback_api_key=x_gemini_api_key,
        )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    today = date.today()
    sleep_hours_calc = (
        extracted.sleep_duration_hours
        if (resolved_source == WearableSource.SAMSUNG_WATCH and extracted.sleep_duration_hours > 0)
        else float(extracted.sleep_hours or 0.0)
    )
    db_resting_hr = int(extracted.resting_hr) if extracted.resting_hr > 0 else None
    db_hrv_ms = float(extracted.hrv_ms) if extracted.hrv_ms > 0 else None
    db_avg_hr = (
        int(extracted.avg_heart_rate)
        if extracted.avg_heart_rate >= 30
        else (max(45, min(160, int(extracted.resting_hr) + 10)) if extracted.resting_hr > 0 else 60)
    )
    db_max_hr = max(db_avg_hr + 20, 120)

    record: Optional[WearableMetric] = None
    try:
        current_user.preferred_wearable = resolved_source

        # Eliminar cualquier fila previa del mismo usuario y fecha en `wearable_metrics`
        await db.execute(
            delete(WearableMetric).where(
                WearableMetric.user_id == current_user.id,
                WearableMetric.date == today,
            )
        )
        new_metric = WearableMetric(
            user_id=current_user.id,
            date=today,
            strain_score=extracted.strain_score,
            recovery_score=extracted.recovery_score,
            hrv_ms=db_hrv_ms,
            resting_hr=db_resting_hr,
            avg_hr=db_avg_hr,
            max_hr=db_max_hr,
            sleep_hours=sleep_hours_calc,
            sleep_efficiency_pct=extracted.sleep_performance_pct,
            source_device=resolved_source,
            synced_at=datetime.now(timezone.utc),
        )
        db.add(new_metric)
        await db.flush()
        record = new_metric
    except Exception as exc:
        logger.warning("Aviso guardando WearableMetric, aplicando rollback parcial: %s", exc)
        await db.rollback()
        record = None

    # UPSERT estricto en `daily_readiness` filtrando por `user_id` y `today`
    try:
        await db.execute(
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
        await db.execute(
            text(
                "DELETE FROM daily_readiness WHERE user_id = :user_id AND date = :date"
            ),
            {"user_id": current_user.id, "date": today},
        )
        await db.execute(
            text(
                """
                INSERT INTO daily_readiness (
                    user_id, date, sleep_pct, recovery_score, strain_score,
                    stress_level, stress_category, sleep_hours, source_device, synced_at
                )
                VALUES (
                    :user_id, :date, :sleep_pct, :recovery_score, :strain_score,
                    :stress_level, :stress_category, :sleep_hours, :source_device, NOW()
                )
                """
            ),
            {
                "user_id": current_user.id,
                "date": today,
                "sleep_pct": extracted.sleep_pct,
                "recovery_score": extracted.recovery_score,
                "strain_score": extracted.strain_score,
                "stress_level": extracted.stress_level,
                "stress_category": extracted.stress_category,
                "sleep_hours": sleep_hours_calc,
                "source_device": resolved_source.value,
            },
        )
        await db.commit()
        if record is not None:
            await db.refresh(record)
    except Exception as exc:
        logger.error("Error en UPSERT de daily_readiness: %s", exc)
        await db.rollback()
        raise HTTPException(
            status_code=400,
            detail=f"Error al guardar telemetría diaria en PostgreSQL: {exc}",
        ) from exc

    now_utc = datetime.now(timezone.utc)
    return WhoopScreenScanResponse(
        status="success",
        data={
            "recovery_score": float(extracted.recovery_score),
            "strain_score": float(extracted.strain_score),
            "sleep_pct": float(extracted.sleep_pct),
            "stress_level": float(extracted.stress_level),
            "stress_category": str(extracted.stress_category),
            "sleep_hours": float(sleep_hours_calc),
            "hrv_ms": float(extracted.hrv_ms),
            "resting_hr": int(extracted.resting_hr),
        },
        id=record.id if record is not None else uuid4(),
        user_id=current_user.id,
        date=today,
        sleep_pct=extracted.sleep_pct,
        sleep_performance_pct=extracted.sleep_performance_pct,
        recovery_score=extracted.recovery_score,
        strain_score=extracted.strain_score,
        stress_level=extracted.stress_level,
        stress_category=extracted.stress_category,
        whoop_stress_level=extracted.stress_level,
        whoop_health_metrics_in_range=5 if extracted.recovery_score > 0 else 0,
        resting_hr=int(extracted.resting_hr),
        hrv_ms=float(extracted.hrv_ms),
        avg_hr=int(extracted.avg_heart_rate) if extracted.avg_heart_rate > 0 else 0,
        max_hr=0,
        sleep_hours=float(sleep_hours_calc),
        sleep_efficiency_pct=extracted.sleep_performance_pct,
        huawei_trusleep_score=extracted.trusleep_score,
        huawei_stress_score=extracted.stress_score,
        huawei_vo2_max=extracted.vo2max,
        samsung_energy_score=extracted.energy_score,
        samsung_bia_muscle_pct=extracted.bia_muscle_pct,
        samsung_bia_fat_pct=extracted.bia_fat_pct,
        source_device=resolved_source,
        synced_at=record.synced_at if record is not None else now_utc,
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
    Endpoint interactivo para el Centro Táctico / Director de Rendimiento (`POST /api/v1/ai/chat`).
    Consume únicamente biometría y telemetría reales del usuario autenticado (cero números quemados).
    """
    bio = await get_athlete_biometrics(db, current_user.id)
    readiness = await get_today_athlete_readiness(db, current_user.id)

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

    client_ctx = dict(payload.athlete_context or {})
    if payload.model_extra:
        client_ctx.update(payload.model_extra)

    rec_val = (
        payload.recovery_score
        if payload.recovery_score is not None
        else (
            client_ctx.get("recovery_score")
            if client_ctx.get("recovery_score") is not None
            else readiness.get("recovery_score")
        )
    )
    sleep_pct_val = (
        payload.sleep_performance_pct
        if payload.sleep_performance_pct is not None
        else (
            client_ctx.get("sleep_performance_pct")
            if client_ctx.get("sleep_performance_pct") is not None
            else readiness.get("sleep_pct")
        )
    )
    strain_val = (
        payload.strain_score
        if payload.strain_score is not None
        else (
            client_ctx.get("strain_score")
            if client_ctx.get("strain_score") is not None
            else readiness.get("strain_score")
        )
    )
    stress_lvl_val = (
        payload.stress_level
        if payload.stress_level is not None
        else (
            client_ctx.get("stress_level")
            if client_ctx.get("stress_level") is not None
            else readiness.get("stress_level")
        )
    )
    stress_cat_val = str(
        payload.stress_category
        or client_ctx.get("stress_category")
        or readiness.get("stress_category")
        or "SIN DATO"
    )

    merged_context: dict[str, Any] = {
        "athlete_name": (
            payload.athlete_name
            or client_ctx.get("athlete_name")
            or current_user.full_name
            or current_user.username
        ),
        "username": current_user.username,
        "sex": bio.get("sex"),
        "training_goal": current_user.training_goal.value,
        "wearable_source": str(
            client_ctx.get("wearable_source")
            or readiness.get("source_device")
            or current_user.preferred_wearable.value
        ),
        "recovery_score": float(rec_val) if rec_val is not None else None,
        "sleep_performance_pct": float(sleep_pct_val) if sleep_pct_val is not None else None,
        "strain_score": float(strain_val) if strain_val is not None else None,
        "stress_level": float(stress_lvl_val) if stress_lvl_val is not None else None,
        "stress_category": stress_cat_val,
        "hydration_ml": int(
            payload.hydration_consumed_ml
            if payload.hydration_consumed_ml is not None
            else (client_ctx.get("hydration_consumed_ml") or client_ctx.get("hydration_ml") or hyd_ml)
        ),
        "hydration_goal_ml": int(
            payload.hydration_goal_ml
            or client_ctx.get("hydration_goal_ml")
            or hyd_goal
        ),
        "weight_kg": bio.get("weight_kg"),
        "lean_body_mass_kg": bio.get("lbm_kg"),
        "fat_percentage": bio.get("body_fat_pct"),
        "routine_name": str(
            payload.scheduled_routine_name
            or client_ctx.get("scheduled_routine_name")
            or client_ctx.get("routine_name")
            or (today_routine.name if today_routine else "Periodización Adaptativa IA")
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
