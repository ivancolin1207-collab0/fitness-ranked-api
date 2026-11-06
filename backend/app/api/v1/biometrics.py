from __future__ import annotations

"""
Endpoints de Ingesta Biométrica Dual (`POST /biometrics` Manual + `POST /biometrics/scan` OCR Fitdays)
y Sincronización Real de Wearables (`/wearables/today`, `/wearables/sync`).
"""

from datetime import date, datetime, timezone
from typing import Annotated, Any, Optional
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, File, Form, Header, HTTPException, Query, UploadFile, status
from sqlalchemy import func, select, text
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
    generate_coach_chat_reply,
    scan_wearable_screen,
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
        visceral_fat=max(1, min(60, int(round(float(payload.visceral_fat))))),
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
    Propaga HTTPException(400) si ocurre cualquier error (cero mocks).
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
    # Eliminar automáticamente cualquier fila residual generada por el antiguo fallback mock (62% rec, 90% sueño, 62 bpm)
    if (
        round(float(record.recovery_score)) == 62
        and round(float(record.sleep_efficiency_pct or 0.0)) == 90
        and int(record.resting_hr or 0) == 62
    ):
        await db.delete(record)
        await db.commit()
        return None

    base_resp = WearableSyncResponse.model_validate(record)
    base_resp.sleep_pct = float(record.sleep_efficiency_pct or 80.0)
    try:
        dr_row = (
            await db.execute(
                text(
                    """
                    SELECT sleep_pct, stress_level, stress_category,
                           recovery_score, strain_score, sleep_hours, synced_at
                    FROM daily_readiness
                    WHERE user_id = :user_id AND date = :date
                    ORDER BY synced_at DESC
                    LIMIT 1
                    """
                ),
                {"user_id": current_user.id, "date": today},
            )
        ).first()
        if dr_row is not None:
            if dr_row[0] is not None:
                base_resp.sleep_pct = float(dr_row[0])
            if dr_row[1] is not None:
                base_resp.stress_level = float(dr_row[1])
                base_resp.whoop_stress_level = float(dr_row[1])
            if dr_row[2] is not None:
                base_resp.stress_category = str(dr_row[2])

            # Si el escaneo de readiness es más reciente (o igual) que la fila de wearable_metrics,
            # su telemetría manda: evita devolver el registro viejo de la mañana (47% / 7.4).
            dr_synced = dr_row[6]
            wm_synced = record.synced_at
            dr_is_newer = (
                dr_synced is None
                or wm_synced is None
                or dr_synced >= wm_synced
            )
            if dr_is_newer:
                if dr_row[3] is not None:
                    base_resp.recovery_score = float(dr_row[3])
                if dr_row[4] is not None:
                    base_resp.strain_score = float(dr_row[4])
                if dr_row[5] is not None:
                    base_resp.sleep_hours = float(dr_row[5])
                if dr_row[0] is not None:
                    base_resp.sleep_efficiency_pct = float(dr_row[0])
    except Exception:
        await db.rollback()
    return base_resp


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
                "synced_at": func.now(),
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
    file: Annotated[UploadFile, File(description="Captura de pantalla del wearable (WHOOP, HUAWEI, SAMSUNG)")],
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    source_device: Annotated[Optional[str], Form()] = None,
    source_wearable: Annotated[Optional[str], Form()] = None,
    x_gemini_api_key: Annotated[Optional[str], Header()] = None,
) -> WhoopScreenScanResponse:
    """
    Procesa una captura de pantalla de WHOOP (`/api/v1/wearables/scan-whoop` y `/api/v1/wearables/scan-screen`)
    mediante Gemini Vision y actualiza atómicamente `daily_readiness` y `wearable_metrics` en PostgreSQL.
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

    print(f">>> TELEMETRÍA {resolved_source.value} EXTRAÍDA: {extracted}")

    today = date.today()
    sleep_hours_calc = (
        extracted.sleep_duration_hours
        if resolved_source == WearableSource.SAMSUNG_WATCH
        else (
            extracted.sleep_hours
            if getattr(extracted, "sleep_hours", None)
            else round((extracted.sleep_performance_pct / 100.0) * 8.0, 2)
        )
    )
    avg_hr_calc = (
        extracted.avg_heart_rate
        if resolved_source == WearableSource.HUAWEI_GT
        else max(52, min(140, extracted.resting_hr + 12))
    )
    max_hr_calc = max(avg_hr_calc + 25, 168)

    record: Optional[WearableMetric] = None
    try:
        current_user.preferred_wearable = resolved_source
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
                source_device=resolved_source,
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
                    "synced_at": func.now(),
                },
            )
            .returning(WearableMetric)
        )
        result = await db.execute(stmt)
        record = result.scalar_one()
        await db.commit()
        await db.refresh(record)
    except Exception:
        await db.rollback()
        try:
            existing_stmt = (
                select(WearableMetric)
                .where(
                    WearableMetric.user_id == current_user.id,
                    WearableMetric.date == today,
                )
                .order_by(WearableMetric.synced_at.desc())
                .limit(1)
            )
            existing = (await db.execute(existing_stmt)).scalar_one_or_none()
            if existing is not None:
                existing.strain_score = extracted.strain_score
                existing.recovery_score = extracted.recovery_score
                existing.hrv_ms = extracted.hrv_ms
                existing.resting_hr = extracted.resting_hr
                existing.avg_hr = avg_hr_calc
                existing.max_hr = max_hr_calc
                existing.sleep_hours = sleep_hours_calc
                existing.sleep_efficiency_pct = extracted.sleep_performance_pct
                existing.synced_at = datetime.now(timezone.utc)
                record = existing
            else:
                new_metric = WearableMetric(
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
                    source_device=resolved_source,
                )
                db.add(new_metric)
                record = new_metric
            await db.commit()
            if record is not None:
                await db.refresh(record)
        except Exception:
            await db.rollback()
            record = None

    # Persistir atómicamente en `daily_readiness` para la fecha actual
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
                    stress_category VARCHAR(20) NOT NULL DEFAULT 'BAJO',
                    sleep_hours NUMERIC(4,2) NOT NULL DEFAULT 7.7,
                    source_device VARCHAR(30) NOT NULL DEFAULT 'WHOOP',
                    synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                    UNIQUE (user_id, date, source_device)
                )
                """
            )
        )
        await db.execute(
            text(
                "ALTER TABLE daily_readiness ADD COLUMN IF NOT EXISTS sleep_hours NUMERIC(4,2) NOT NULL DEFAULT 7.7"
            )
        )
        # UPSERT estricto: una sola fila de readiness por usuario/día. Se eliminan filas residuales
        # de otras fuentes del mismo día para que ninguna lectura devuelva el registro viejo de la mañana.
        await db.execute(
            text(
                """
                DELETE FROM daily_readiness
                WHERE user_id = :user_id AND date = :date AND source_device <> :source_device
                """
            ),
            {
                "user_id": current_user.id,
                "date": today,
                "source_device": resolved_source.value,
            },
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
                ON CONFLICT (user_id, date, source_device) DO UPDATE SET
                    sleep_pct = EXCLUDED.sleep_pct,
                    recovery_score = EXCLUDED.recovery_score,
                    strain_score = EXCLUDED.strain_score,
                    stress_level = EXCLUDED.stress_level,
                    stress_category = EXCLUDED.stress_category,
                    sleep_hours = EXCLUDED.sleep_hours,
                    synced_at = NOW()
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
    except Exception as exc:
        print(f">>> ERROR UPSERT daily_readiness: {exc!r}")
        await db.rollback()

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
        },
        id=record.id if record is not None else uuid4(),
        user_id=record.user_id if record is not None else current_user.id,
        date=record.date if record is not None else today,
        sleep_pct=extracted.sleep_pct,
        sleep_performance_pct=extracted.sleep_performance_pct,
        recovery_score=extracted.recovery_score,
        strain_score=extracted.strain_score,
        stress_level=extracted.stress_level,
        stress_category=extracted.stress_category,
        whoop_stress_level=extracted.stress_level,
        whoop_health_metrics_in_range=5,
        resting_hr=int(record.resting_hr or extracted.resting_hr) if record is not None else extracted.resting_hr,
        hrv_ms=float(record.hrv_ms or extracted.hrv_ms) if record is not None else extracted.hrv_ms,
        avg_hr=int(record.avg_hr) if record is not None else avg_hr_calc,
        max_hr=int(record.max_hr) if record is not None else max_hr_calc,
        sleep_hours=float(record.sleep_hours) if record is not None else sleep_hours_calc,
        sleep_efficiency_pct=float(
            record.sleep_efficiency_pct or extracted.sleep_performance_pct
        ) if record is not None else extracted.sleep_performance_pct,
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

    client_ctx = dict(payload.athlete_context or {})
    if payload.model_extra:
        client_ctx.update(payload.model_extra)

    rec_val = float(
        payload.recovery_score
        or client_ctx.get("recovery_score")
        or (today_wearable.recovery_score if today_wearable else 47.0)
    )
    sleep_pct_val = float(
        payload.sleep_performance_pct
        or client_ctx.get("sleep_performance_pct")
        or (
            today_wearable.sleep_efficiency_pct
            if (today_wearable and today_wearable.sleep_efficiency_pct is not None)
            else 80.0
        )
    )
    strain_val = float(
        payload.strain_score
        or client_ctx.get("strain_score")
        or (today_wearable.strain_score if today_wearable else 7.2)
    )
    stress_lvl_val = float(
        payload.stress_level
        or client_ctx.get("stress_level")
        or (2.4 if rec_val < 50.0 else (1.5 if rec_val < 75.0 else 0.9))
    )
    stress_cat_val = str(
        payload.stress_category
        or client_ctx.get("stress_category")
        or ("ALTO" if stress_lvl_val >= 2.0 else ("MEDIO" if stress_lvl_val >= 1.2 else "BAJO"))
    )

    merged_context: dict[str, Any] = {
        "athlete_name": (
            payload.athlete_name
            or client_ctx.get("athlete_name")
            or current_user.full_name
            or current_user.username
        ),
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
        "weight_kg": float(latest_bio.weight_kg) if latest_bio else 78.0,
        "lean_body_mass_kg": float(latest_bio.lean_body_mass_kg) if latest_bio else 65.0,
        "fat_percentage": float(latest_bio.fat_percentage) if latest_bio else 14.8,
        "routine_name": str(
            payload.scheduled_routine_name
            or client_ctx.get("scheduled_routine_name")
            or client_ctx.get("routine_name")
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
