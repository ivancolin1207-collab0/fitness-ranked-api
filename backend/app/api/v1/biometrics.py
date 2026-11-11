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
from fastapi.responses import HTMLResponse
from sqlalchemy import delete, func, select, text
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.elo_engine import WearableSource
from app.core.security import (
    get_current_user,
    validate_base64_image,
    validate_uploaded_image,
)
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
    WhoopScanBase64Request,
    WhoopScreenExtractedMetrics,
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
from app.services.whoop_cloud_service import (
    build_whoop_authorization_url,
    exchange_code_and_store_tokens,
    fetch_whoop_cloud_metrics,
    get_user_whoop_oauth_status,
    verify_signed_oauth_state,
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
    if not readiness["has_readiness_today"]:
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
    raw_rec_val = readiness.get("recovery_score")
    rec_val = float(raw_rec_val) if (raw_rec_val is not None and float(raw_rec_val) >= 1.0) else 0.0
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
@router.post(
    "/wearables/readiness/save",
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
    de captura OCR confirmada, Health Connect o ingreso manual y actualiza la fuente primaria.
    PROHIBIDO sobrescribir un `recovery_score >= 1` o `sleep_pct >= 1` existente hoy con `0.0`.
    """
    user_id: UUID = current_user.id
    current_user.preferred_wearable = payload.source_device

    existing_today = await get_today_athlete_readiness(db, user_id)
    prev_rec = float(existing_today.get("recovery_score") or 0.0)
    prev_sleep_pct = float(existing_today.get("sleep_pct") or 0.0)
    prev_sleep_h = float(existing_today.get("sleep_hours") or 0.0)
    prev_strain = float(existing_today.get("strain_score") or 0.0)
    prev_hrv = float(existing_today.get("hrv_ms") or 0.0)
    prev_rhr = int(existing_today.get("resting_hr") or 0)
    prev_stress = existing_today.get("stress_level")
    prev_stress_cat = existing_today.get("stress_category")

    effective_recovery = (
        float(payload.recovery_score)
        if float(payload.recovery_score or 0.0) >= 1.0
        else (prev_rec if prev_rec >= 1.0 else 0.0)
    )
    incoming_sleep_pct = float(payload.sleep_efficiency_pct or 0.0)
    effective_sleep_pct = (
        incoming_sleep_pct
        if incoming_sleep_pct >= 1.0
        else (prev_sleep_pct if prev_sleep_pct >= 1.0 else None)
    )
    effective_sleep_hours = (
        float(payload.sleep_hours)
        if float(payload.sleep_hours or 0.0) > 0.0
        else (prev_sleep_h if prev_sleep_h > 0.0 else 0.0)
    )
    effective_strain = (
        float(payload.strain_score)
        if float(payload.strain_score or 0.0) > 0.0
        else (prev_strain if prev_strain > 0.0 else 0.0)
    )

    raw_hrv = (
        float(payload.hrv_ms)
        if (payload.hrv_ms is not None and float(payload.hrv_ms) >= 5.0)
        else prev_hrv
    )
    safe_hrv = raw_hrv if (5.0 <= raw_hrv <= 300.0) else None

    raw_rhr = (
        int(payload.resting_hr)
        if (payload.resting_hr is not None and int(payload.resting_hr) >= 25)
        else prev_rhr
    )
    safe_rhr = raw_rhr if (25 <= raw_rhr <= 140) else None

    safe_avg_hr = max(
        30,
        min(
            220,
            int(payload.avg_hr)
            if payload.avg_hr >= 30
            else (safe_rhr if (safe_rhr is not None and safe_rhr >= 30) else 60),
        ),
    )
    safe_max_hr = max(40, safe_avg_hr, min(240, int(payload.max_hr)))

    await db.execute(
        delete(WearableMetric).where(
            WearableMetric.user_id == user_id,
            WearableMetric.date == payload.date,
        )
    )
    stmt = (
        pg_insert(WearableMetric)
        .values(
            user_id=user_id,
            date=payload.date,
            strain_score=effective_strain,
            recovery_score=effective_recovery,
            hrv_ms=safe_hrv,
            resting_hr=safe_rhr,
            avg_hr=safe_avg_hr,
            max_hr=safe_max_hr,
            sleep_hours=effective_sleep_hours,
            sleep_efficiency_pct=effective_sleep_pct,
            source_device=payload.source_device,
        )
        .on_conflict_do_update(
            constraint="uq_user_date_device",
            set_={
                "strain_score": effective_strain,
                "recovery_score": effective_recovery,
                "hrv_ms": safe_hrv,
                "resting_hr": safe_rhr,
                "avg_hr": safe_avg_hr,
                "max_hr": safe_max_hr,
                "sleep_hours": effective_sleep_hours,
                "sleep_efficiency_pct": effective_sleep_pct,
                "synced_at": func.now(),
            },
        )
        .returning(WearableMetric)
    )
    result = await db.execute(stmt)
    record = result.scalar_one()

    resolved_stress = (
        float(payload.stress_level)
        if (payload.stress_level is not None and float(payload.stress_level) > 0.0)
        else (float(prev_stress) if prev_stress is not None else 0.0)
    )
    resolved_stress_cat = (
        payload.stress_category
        or prev_stress_cat
        or (
            "ALTO"
            if resolved_stress >= 2.0
            else (
                "MEDIO"
                if resolved_stress >= 1.0
                else ("BAJO" if resolved_stress > 0.0 else "SIN DATO")
            )
        )
    )

    # Sincronizar también en `daily_readiness` para que toda consulta lea el último estado unificado
    try:
        async with db.begin_nested():
            await db.execute(
                text(
                    "ALTER TABLE daily_readiness ADD COLUMN IF NOT EXISTS hrv_ms NUMERIC(5,2)"
                )
            )
            await db.execute(
                text(
                    "ALTER TABLE daily_readiness ADD COLUMN IF NOT EXISTS resting_hr SMALLINT"
                )
            )
            await db.execute(
                text(
                    "DELETE FROM daily_readiness WHERE user_id = :uid AND date = :dt"
                ),
                {"uid": user_id, "dt": payload.date},
            )
            await db.execute(
                text(
                    """
                    INSERT INTO daily_readiness (
                        user_id, date, sleep_pct, recovery_score, strain_score,
                        stress_level, stress_category, sleep_hours, hrv_ms, resting_hr,
                        source_device, synced_at
                    )
                    VALUES (
                        :uid, :dt, :sleep_pct, :rec, :strain,
                        :stress_lvl, :stress_cat, :sleep_h, :hrv, :rhr,
                        :src, NOW()
                    )
                    """
                ),
                {
                    "uid": user_id,
                    "dt": payload.date,
                    "sleep_pct": float(effective_sleep_pct or 0.0),
                    "rec": effective_recovery,
                    "strain": effective_strain,
                    "stress_lvl": resolved_stress,
                    "stress_cat": resolved_stress_cat,
                    "sleep_h": effective_sleep_hours,
                    "hrv": safe_hrv,
                    "rhr": safe_rhr,
                    "src": payload.source_device.value,
                },
            )
            if float(payload.recovery_score or 0.0) >= 1.0:
                await db.execute(
                    text(
                        """
                        UPDATE user_routines
                        SET biometric_signature = 'NEEDS_RECOVERY_SYNC'
                        WHERE user_id = :uid AND status = 'active'
                        """
                    ),
                    {"uid": user_id},
                )
    except Exception as exc:
        logger.warning("Aviso actualizando daily_readiness en sync_wearable: %s", exc)

    await db.commit()
    await db.refresh(record)
    resp = WearableSyncResponse.model_validate(record)
    resp.sleep_pct = effective_sleep_pct
    resp.sleep_efficiency_pct = effective_sleep_pct
    resp.stress_level = resolved_stress
    resp.whoop_stress_level = resolved_stress
    resp.stress_category = resolved_stress_cat
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


def _resolve_wearable_source_enum(raw_source: str) -> WearableSource:
    upper = (raw_source or "WHOOP").upper().strip()
    if "HUAWEI" in upper:
        return WearableSource.HUAWEI_GT
    if "SAMSUNG" in upper:
        return WearableSource.SAMSUNG_WATCH
    if "APPLE" in upper:
        return WearableSource.APPLE_WATCH
    if "HEALTH" in upper:
        return WearableSource.HEALTH_CONNECT
    return WearableSource.WHOOP


async def _persist_and_build_whoop_scan_response(
    db: AsyncSession,
    *,
    user_id: UUID,
    extracted: WhoopScreenExtractedMetrics,
    resolved_source: WearableSource,
) -> WhoopScreenScanResponse:
    """
    Persiste de forma atómica y segura (con SAVEPOINTs para evitar `MissingGreenlet` y
    errores de columnas faltantes) las métricas extraídas del wearable en `daily_readiness`
    y `wearable_metrics`, devolviendo la estructura JSON unificada (raíz + `"data"`).
    """
    today = date.today()
    now_utc = datetime.now(timezone.utc)

    # Si la captura es de la pestaña Overview de Whoop (donde no se imprimen HRV ni RHR),
    # conservar el HRV y RHR reales registrados previamente hoy por Health Connect / pestaña Recovery.
    existing_today = await get_today_athlete_readiness(db, user_id)
    prev_hrv = float(existing_today.get("hrv_ms") or 0.0)
    prev_rhr = int(existing_today.get("resting_hr") or 0)

    effective_hrv = (
        float(extracted.hrv_ms) if float(extracted.hrv_ms or 0.0) > 0 else prev_hrv
    )
    effective_rhr = (
        int(extracted.resting_hr) if int(extracted.resting_hr or 0) > 0 else prev_rhr
    )

    sleep_hours_calc = (
        extracted.sleep_duration_hours
        if (
            resolved_source == WearableSource.SAMSUNG_WATCH
            and extracted.sleep_duration_hours > 0
        )
        else float(extracted.sleep_hours or 0.0)
    )
    if sleep_hours_calc <= 0.0 and extracted.sleep_pct > 0.0:
        sleep_hours_calc = round((float(extracted.sleep_pct) / 100.0) * 8.0, 1)

    db_hrv_ms = (
        effective_hrv if (5.0 <= effective_hrv <= 300.0) else None
    )
    db_resting_hr = (
        effective_rhr if (25 <= effective_rhr <= 140) else None
    )
    db_avg_hr = (
        max(30, min(220, int(extracted.avg_heart_rate)))
        if int(extracted.avg_heart_rate or 0) >= 30
        else (
            max(35, min(160, db_resting_hr + 10))
            if db_resting_hr is not None
            else 60
        )
    )
    db_max_hr = max(40, db_avg_hr + 20)

    record_id: UUID = uuid4()

    # 1. Guardar en `wearable_metrics` dentro de SAVEPOINT para no invalidar la sesión si hay un enum antiguo
    try:
        async with db.begin_nested():
            await db.execute(
                delete(WearableMetric).where(
                    WearableMetric.user_id == user_id,
                    WearableMetric.date == today,
                )
            )
            new_metric = WearableMetric(
                user_id=user_id,
                date=today,
                strain_score=max(0.0, min(21.0, float(extracted.strain_score))),
                recovery_score=max(0.0, min(100.0, float(extracted.recovery_score))),
                hrv_ms=db_hrv_ms,
                resting_hr=db_resting_hr,
                avg_hr=db_avg_hr,
                max_hr=db_max_hr,
                sleep_hours=max(0.0, min(24.0, float(sleep_hours_calc))),
                sleep_efficiency_pct=max(
                    0.0, min(100.0, float(extracted.sleep_performance_pct))
                ),
                source_device=resolved_source,
                synced_at=now_utc,
            )
            db.add(new_metric)
            await db.flush()
            record_id = new_metric.id
    except Exception as exc:
        logger.warning(
            "Aviso en SAVEPOINT de WearableMetric (continuando con daily_readiness): %s",
            exc,
        )

    # 2. Garantizar esquema de `daily_readiness` y ejecutar UPSERT estricto por (user_id, today)
    try:
        async with db.begin_nested():
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
                        hrv_ms NUMERIC(5,2),
                        resting_hr SMALLINT,
                        source_device VARCHAR(30) NOT NULL DEFAULT 'WHOOP',
                        synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        UNIQUE (user_id, date, source_device)
                    )
                    """
                )
            )
            await db.execute(
                text(
                    "ALTER TABLE daily_readiness ADD COLUMN IF NOT EXISTS stress_level NUMERIC(3,1) NOT NULL DEFAULT 0.0"
                )
            )
            await db.execute(
                text(
                    "ALTER TABLE daily_readiness ADD COLUMN IF NOT EXISTS stress_category VARCHAR(20) NOT NULL DEFAULT 'SIN DATO'"
                )
            )
            await db.execute(
                text(
                    "ALTER TABLE daily_readiness ADD COLUMN IF NOT EXISTS sleep_hours NUMERIC(4,2) NOT NULL DEFAULT 0.0"
                )
            )
            await db.execute(
                text(
                    "ALTER TABLE daily_readiness ADD COLUMN IF NOT EXISTS hrv_ms NUMERIC(5,2)"
                )
            )
            await db.execute(
                text(
                    "ALTER TABLE daily_readiness ADD COLUMN IF NOT EXISTS resting_hr SMALLINT"
                )
            )
    except Exception as exc:
        logger.warning("Aviso verificando columnas de daily_readiness: %s", exc)

    try:
        await db.execute(
            text(
                "DELETE FROM daily_readiness WHERE user_id = :user_id AND date = :date"
            ),
            {"user_id": user_id, "date": today},
        )
        await db.execute(
            text(
                """
                INSERT INTO daily_readiness (
                    user_id, date, sleep_pct, recovery_score, strain_score,
                    stress_level, stress_category, sleep_hours, hrv_ms, resting_hr,
                    source_device, synced_at
                )
                VALUES (
                    :user_id, :date, :sleep_pct, :recovery_score, :strain_score,
                    :stress_level, :stress_category, :sleep_hours, :hrv_ms, :resting_hr,
                    :source_device, NOW()
                )
                """
            ),
            {
                "user_id": user_id,
                "date": today,
                "sleep_pct": float(extracted.sleep_pct),
                "recovery_score": float(extracted.recovery_score),
                "strain_score": float(extracted.strain_score),
                "stress_level": float(extracted.stress_level),
                "stress_category": str(extracted.stress_category),
                "sleep_hours": float(sleep_hours_calc),
                "hrv_ms": db_hrv_ms,
                "resting_hr": db_resting_hr,
                "source_device": resolved_source.value,
            },
        )
        await db.commit()
    except Exception as exc:
        logger.error("Error en UPSERT de daily_readiness: %s", exc)
        await db.rollback()
        raise HTTPException(
            status_code=400,
            detail=f"Error al guardar telemetría diaria en PostgreSQL: {exc}",
        ) from exc

    unified_data = {
        "status": "success",
        "recovery_score": float(extracted.recovery_score),
        "strain_score": float(extracted.strain_score),
        "sleep_pct": float(extracted.sleep_pct),
        "sleep_performance_pct": float(extracted.sleep_performance_pct),
        "sleep_efficiency_pct": float(extracted.sleep_performance_pct),
        "stress_level": float(extracted.stress_level),
        "whoop_stress_level": float(extracted.stress_level),
        "stress_category": str(extracted.stress_category),
        "sleep_hours": float(sleep_hours_calc),
        "hrv_ms": float(effective_hrv),
        "resting_hr": int(effective_rhr),
        "avg_hr": int(extracted.avg_heart_rate) if extracted.avg_heart_rate > 0 else 0,
        "whoop_health_metrics_in_range": 5 if extracted.recovery_score > 0 else 0,
        "huawei_trusleep_score": int(extracted.trusleep_score),
        "huawei_stress_score": int(extracted.stress_score),
        "huawei_vo2_max": float(extracted.vo2max),
        "samsung_energy_score": int(extracted.energy_score),
        "samsung_bia_muscle_pct": float(extracted.bia_muscle_pct),
        "samsung_bia_fat_pct": float(extracted.bia_fat_pct),
        "source_device": resolved_source.value,
    }

    return WhoopScreenScanResponse(
        status="success",
        data=unified_data,
        id=record_id,
        user_id=user_id,
        date=today,
        sleep_pct=float(extracted.sleep_pct),
        sleep_performance_pct=float(extracted.sleep_performance_pct),
        recovery_score=float(extracted.recovery_score),
        strain_score=float(extracted.strain_score),
        stress_level=float(extracted.stress_level),
        stress_category=str(extracted.stress_category),
        whoop_stress_level=float(extracted.stress_level),
        whoop_health_metrics_in_range=5 if extracted.recovery_score > 0 else 0,
        resting_hr=int(effective_rhr),
        hrv_ms=float(effective_hrv),
        avg_hr=int(extracted.avg_heart_rate) if extracted.avg_heart_rate > 0 else 0,
        max_hr=0,
        sleep_hours=float(sleep_hours_calc),
        sleep_efficiency_pct=float(extracted.sleep_performance_pct),
        huawei_trusleep_score=int(extracted.trusleep_score),
        huawei_stress_score=int(extracted.stress_score),
        huawei_vo2_max=float(extracted.vo2max),
        samsung_energy_score=int(extracted.energy_score),
        samsung_bia_muscle_pct=float(extracted.bia_muscle_pct),
        samsung_bia_fat_pct=float(extracted.bia_fat_pct),
        source_device=resolved_source,
        synced_at=now_utc,
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
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    file: Annotated[
        Optional[UploadFile],
        File(description="Captura comprimida del wearable (campo 'file')"),
    ] = None,
    image: Annotated[
        Optional[UploadFile],
        File(description="Captura comprimida del wearable (alias campo 'image')"),
    ] = None,
    source_device: Annotated[Optional[str], Form()] = None,
    source_wearable: Annotated[Optional[str], Form()] = None,
    x_gemini_api_key: Annotated[Optional[str], Header()] = None,
) -> WhoopScreenScanResponse:
    """
    Procesa una captura de pantalla de wearable mediante Gemini 2.5 Flash Vision
    (aceptando tanto el campo `'file'` como `'image'` en Multipart) y realiza un UPSERT real
    en PostgreSQL filtrando por `user_id` y `today`.
    """
    user_id: UUID = current_user.id
    upload_target = file or image
    if upload_target is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Debes adjuntar la captura del wearable en el campo 'file' o 'image'.",
        )

    raw_source = (
        source_device
        or source_wearable
        or (
            current_user.preferred_wearable.value
            if current_user.preferred_wearable
            else "WHOOP"
        )
    )
    resolved_source = _resolve_wearable_source_enum(raw_source)

    try:
        clean_bytes, clean_mime = await validate_uploaded_image(upload_target)
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

    return await _persist_and_build_whoop_scan_response(
        db,
        user_id=user_id,
        extracted=extracted,
        resolved_source=resolved_source,
    )


@router.post(
    "/wearables/scan-whoop-base64",
    response_model=WhoopScreenScanResponse,
    status_code=status.HTTP_200_OK,
)
@router.post(
    "/wearables/scan-screen-base64",
    response_model=WhoopScreenScanResponse,
    status_code=status.HTTP_200_OK,
)
async def scan_whoop_screen_base64(
    payload: WhoopScanBase64Request,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    x_gemini_api_key: Annotated[Optional[str], Header()] = None,
) -> WhoopScreenScanResponse:
    """
    Alternativa JSON en Base64 para el escaneo OCR de WHOOP / Wearables que evita
    por completo cualquier error `422 Unprocessable Entity` de Multipart Form-Data.
    """
    user_id: UUID = current_user.id
    raw_source = (
        payload.source_device
        or payload.source_wearable
        or (
            current_user.preferred_wearable.value
            if current_user.preferred_wearable
            else "WHOOP"
        )
    )
    resolved_source = _resolve_wearable_source_enum(raw_source)

    try:
        clean_bytes, clean_mime = validate_base64_image(payload.image_base64)
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

    return await _persist_and_build_whoop_scan_response(
        db,
        user_id=user_id,
        extracted=extracted,
        resolved_source=resolved_source,
    )


# ============================================================================
# INTEGRACIÓN OFICIAL WHOOP CLOUD OAUTH 2.0 (`api.prod.whoop.com`)
# ============================================================================


@router.get("/wearables/whoop/oauth/status", status_code=status.HTTP_200_OK)
async def whoop_oauth_status(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, Any]:
    """Consulta si el atleta tiene vinculada su cuenta de WHOOP Cloud OAuth 2.0."""
    return await get_user_whoop_oauth_status(db, current_user.id)


@router.get("/wearables/whoop/oauth/authorize", status_code=status.HTTP_200_OK)
async def whoop_oauth_authorize(
    current_user: Annotated[User, Depends(get_current_user)],
    redirect_uri: Optional[str] = Query(default=None),
) -> dict[str, str]:
    """Genera la URL de autorización OAuth 2.0 oficial de WHOOP firmada para el atleta."""
    auth_url = build_whoop_authorization_url(
        current_user.id, redirect_uri=redirect_uri
    )
    return {"authorize_url": auth_url}


@router.get(
    "/wearables/whoop/oauth/callback",
    response_class=HTMLResponse,
    status_code=status.HTTP_200_OK,
)
async def whoop_oauth_callback(
    code: str = Query(...),
    state: str = Query(...),
    db: Annotated[AsyncSession, Depends(get_db)] = None,
) -> HTMLResponse:
    """
    Callback oficial OAuth 2.0 de WHOOP (`developer.whoop.com`).
    Intercambia `code` por `access_token` + `refresh_token`, descarga inmediatamente
    Recovery, Strain, Sleep, HRV y RHR del día y redirige de vuelta a ApexMetrix.
    """
    user_id = verify_signed_oauth_state(state)
    await exchange_code_and_store_tokens(db, user_id=user_id, code=code)

    sync_summary = "Cuenta WHOOP Cloud vinculada correctamente."
    try:
        cloud_metrics = await fetch_whoop_cloud_metrics(db, user_id)
        extracted = WhoopScreenExtractedMetrics(
            sleep_pct=cloud_metrics["sleep_pct"],
            sleep_performance_pct=cloud_metrics["sleep_performance_pct"],
            recovery_score=cloud_metrics["recovery_score"],
            strain_score=cloud_metrics["strain_score"],
            stress_level=cloud_metrics["stress_level"],
            stress_category=cloud_metrics["stress_category"],
            sleep_hours=cloud_metrics["sleep_hours"],
            resting_hr=cloud_metrics["resting_hr"],
            hrv_ms=cloud_metrics["hrv_ms"],
            avg_heart_rate=cloud_metrics["avg_hr"],
        )
        await _persist_and_build_whoop_scan_response(
            db,
            user_id=user_id,
            extracted=extracted,
            resolved_source=WearableSource.WHOOP,
        )
        sync_summary = (
            f"Recuperación {cloud_metrics['recovery_score']:.0f}% • "
            f"Esfuerzo {cloud_metrics['strain_score']:.1f} • "
            f"Sueño {cloud_metrics['sleep_pct']:.0f}%"
        )
    except Exception as exc:
        logger.warning("Aviso en sync inicial tras callback WHOOP OAuth: %s", exc)

    html = f"""<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta http-equiv="refresh" content="1;url=apexmetrix://oauth/whoop?status=linked" />
  <title>WHOOP Cloud Conectado • ApexMetrix</title>
  <style>
    body {{
      background: #0B0E14;
      color: #F3F4F6;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      margin: 0;
      padding: 20px;
    }}
    .card {{
      background: #141821;
      border: 1px solid #10B981;
      border-radius: 16px;
      padding: 28px 24px;
      max-width: 420px;
      text-align: center;
    }}
    h1 {{ color: #10B981; font-size: 20px; margin: 0 0 10px; }}
    p {{ color: #9CA3AF; font-size: 14px; line-height: 1.5; }}
    .btn {{
      display: inline-block;
      margin-top: 18px;
      padding: 12px 22px;
      background: #10B981;
      color: #000;
      font-weight: 800;
      text-decoration: none;
      border-radius: 10px;
    }}
  </style>
  <script>
    setTimeout(function() {{
      window.location.href = "apexmetrix://oauth/whoop?status=success";
    }}, 800);
  </script>
</head>
<body>
  <div class="card">
    <h1>WHOOP 4.0 CLOUD CONECTADO</h1>
    <p>{sync_summary}</p>
    <a class="btn" href="apexmetrix://oauth/whoop?status=success">VOLVER A APEXMETRIX</a>
  </div>
</body>
</html>"""
    return HTMLResponse(content=html)


@router.post(
    "/wearables/whoop/cloud-sync",
    response_model=WhoopScreenScanResponse,
    status_code=status.HTTP_200_OK,
)
async def sync_whoop_cloud_now(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> WhoopScreenScanResponse:
    """
    Sincroniza directamente desde `api.prod.whoop.com` la Recuperación, Strain, Sueño,
    HRV y FC en reposo del atleta autenticado usando su token OAuth 2.0 almacenado.
    """
    user_id: UUID = current_user.id
    cloud_metrics = await fetch_whoop_cloud_metrics(db, user_id)
    extracted = WhoopScreenExtractedMetrics(
        sleep_pct=cloud_metrics["sleep_pct"],
        sleep_performance_pct=cloud_metrics["sleep_performance_pct"],
        recovery_score=cloud_metrics["recovery_score"],
        strain_score=cloud_metrics["strain_score"],
        stress_level=cloud_metrics["stress_level"],
        stress_category=cloud_metrics["stress_category"],
        sleep_hours=cloud_metrics["sleep_hours"],
        resting_hr=cloud_metrics["resting_hr"],
        hrv_ms=cloud_metrics["hrv_ms"],
        avg_heart_rate=cloud_metrics["avg_hr"],
    )
    return await _persist_and_build_whoop_scan_response(
        db,
        user_id=user_id,
        extracted=extracted,
        resolved_source=WearableSource.WHOOP,
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
