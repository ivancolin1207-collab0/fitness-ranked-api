from __future__ import annotations

"""
Servicio de Inteligencia Artificial con Google GenAI SDK (`google-genai`):
1. OCR Biométrico Multimodal (Screenshots de reportes Fitdays / Bioimpedancia).
2. Coach Adaptativo en Tiempo Real (`temperature=0.2` + `response_schema` determinista).
"""

import json
import logging
from typing import Any

from fastapi import HTTPException, status

from app.core.config import get_settings
from app.schemas.biometrics import FitdaysExtractedMetrics
from app.schemas.workouts import AdaptivePrescriptionResponse, PrescribedSetItem

logger = logging.getLogger(__name__)

FITDAYS_OCR_SYSTEM_PROMPT = """
Eres un sistema experto en metrología corporal y lectura OCR de reportes clínicos de bioimpedancia (Fitdays / InBody).
Analiza la captura de pantalla adjunta y extrae con precisión exacta los siguientes indicadores numéricos:
- `weight_kg`: Peso corporal total convertido a kilogramos (si está en lb, divide entre 2.20462).
- `fat_percentage`: Porcentaje de grasa corporal (%).
- `muscle_mass_kg`: Masa muscular en kilogramos (kg).
- `skeletal_muscle_pct`: Porcentaje de músculo esquelético (%).
- `visceral_fat`: Índice de grasa visceral (entero entre 1 y 60).
- `body_water_pct`: Porcentaje de agua corporal total (%).
- `bmr`: Tasa Metabólica Basal en kcal/día (entero).
- `ocr_confidence`: Nivel de confianza de la lectura entre 0.0 y 1.0.
Devuelve exclusivamente un objeto JSON válido que cumpla con el esquema `FitdaysExtractedMetrics`.
""".strip()

COACH_ADAPTIVE_SYSTEM_PROMPT = """
Eres un Fisiólogo del Ejercicio Clínico (CSCS) y AI Fit Coach Personalizado por Atleta en Tiempo Real.
Recibes en `athlete_context` el perfil biométrico completo del atleta:
- Wearable específico (`source_device`: WHOOP, HUAWEI_GT, SAMSUNG_WATCH, APPLE_WATCH).
- Sueño (`sleep_hours`, `sleep_efficiency_pct`), estrés/VFC (`hrv_ms`, `resting_hr`), `recovery_score` y `strain_score`.
- Bioimpedancia Fitdays (`weight_kg`, `fat_percentage`, `muscle_mass_kg`, `body_water_pct`, `visceral_fat`, `bmr`).
- Hidratación diaria consumida hoy (`hydration_ml_today` vs `hydration_goal_ml`).

Calcula de forma determinista y biomecánicamente segura las cargas (`prescribed_weight_kg`),
repeticiones (`prescribed_reps`) y esfuerzo (`prescribed_rpe`) de las series restantes:
1. ZONA ROJA (`recovery_score < 40.0` o `sleep_efficiency_pct < 70.0` o `sleep_hours < 5.8`): Reduce el volumen o carga planeada entre -15% y -25% de peso, cambia enfoque a hipertrofia moderada/movilidad (`prescribed_rpe <= 6.5`) y en `adjustment_rationale` explica cómo el sueño/estrés detectado por su wearable y su hidratación diaria motivaron la descarga para evitar fatiga del SNC.
2. DÉFICIT DE HIDRATACIÓN (`hydration_ml_today < 1000`): Si el agua consumida hoy es baja (< 1.0 L), advierte brevemente en `adjustment_rationale` y modera el RPE objetivo (-0.5 RPE) para proteger el rendimiento neuromuscular.
3. ZONA VERDE (`recovery_score > 80.0`): Si la serie previa fue exitosa (`completed_binary_ui == true` y `actual_rpe <= prescribed_rpe`), aplica sobrecarga progresiva (+2.5 kg en sistema KG o +2.27 kg / +5 lb en sistema LB).
4. FALLO O FATIGA AGUDA (`completed_binary_ui == false` o `actual_reps < prescribed_reps` o `actual_rpe >= 9.5`): Reduce inmediatamente la carga entre -5% y -10% (mínimo -2.5 kg) en las series restantes.
5. GUARDRAIL: Nunca prescribas un peso mayor al 95% de `historical_1rm_kg` y redondea siempre a múltiplos de 2.5 kg.
""".strip()


def round_to_plate_increment(weight_kg: float, step: float = 2.5) -> float:
    """Redondea la carga al incremento físico de discos olímpicos más cercano."""
    return round(round(weight_kg / step) * step, 2)


async def extract_fitdays_biometrics_from_image(
    image_bytes: bytes,
    mime_type: str = "image/jpeg",
) -> FitdaysExtractedMetrics:
    """
    Procesa una imagen de reporte Fitdays mediante Gemini 2.5 Flash Vision
    y devuelve las métricas biométricas estructuradas y validadas.
    """
    settings = get_settings()
    if not settings.GEMINI_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="GEMINI_API_KEY no configurada en el servidor para procesamiento OCR.",
        )

    try:
        from google import genai
        from google.genai import types

        client = genai.Client(api_key=settings.GEMINI_API_KEY)
        image_part = types.Part.from_bytes(data=image_bytes, mime_type=mime_type)

        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=[
                image_part,
                "Extrae todas las métricas biométricas de este reporte Fitdays en formato JSON.",
            ],
            config=types.GenerateContentConfig(
                system_instruction=FITDAYS_OCR_SYSTEM_PROMPT,
                temperature=0.1,
                top_p=0.8,
                max_output_tokens=512,
                response_mime_type="application/json",
                response_schema=FitdaysExtractedMetrics,
            ),
        )
        return FitdaysExtractedMetrics.model_validate_json(response.text)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Error procesando OCR de Fitdays con Gemini Vision: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="No fue posible extraer métricas biométricas válidas de la imagen.",
        ) from exc


def deterministic_fallback_prescription(
    recovery_score: float,
    historical_1rm_kg: float,
    completed_binary: bool,
    prescribed_weight_kg: float,
    prescribed_reps: int,
    prescribed_rpe: float,
    actual_weight_kg: float,
    actual_reps: int,
    actual_rpe: float,
    remaining_sets: list[int],
    unit_system: str = "KG",
    sleep_efficiency_pct: float = 85.0,
    hydration_ml_today: int = 2000,
    source_device: str = "WHOOP",
) -> AdaptivePrescriptionResponse:
    """
    Motor determinista de prescripción y guardrail biomecánico de respaldo.
    """
    overload_step = 2.5 if unit_system == "KG" else 2.27
    low_sleep_or_stress = sleep_efficiency_pct < 70.0
    low_hydration = hydration_ml_today < 1000

    if recovery_score < 40.0 or low_sleep_or_stress:
        zone = "RED_DELOAD"
        target_rpe = min(6.5, prescribed_rpe)
    elif recovery_score > 80.0:
        zone = "GREEN_OVERLOAD"
        target_rpe = min(9.0, max(8.0, prescribed_rpe))
    else:
        zone = "YELLOW_MAINTENANCE"
        target_rpe = prescribed_rpe

    if low_hydration and zone != "RED_DELOAD":
        target_rpe = max(6.5, round(target_rpe - 0.5, 1))

    hydration_suffix = (
        f" Hidratación baja hoy ({hydration_ml_today} ml): hidrátate entre series."
        if low_hydration
        else ""
    )

    if not completed_binary or actual_reps < prescribed_reps or actual_rpe >= 9.5:
        next_weight = round_to_plate_increment(max(20.0, actual_weight_kg * 0.925))
        next_reps = max(
            1,
            prescribed_reps if actual_reps >= prescribed_reps - 1 else prescribed_reps - 1,
        )
        rationale = (
            f"Ajuste reactivo ({source_device}): RPE {actual_rpe} superó el umbral objetivo. "
            f"Carga ajustada a {next_weight} kg para proteger técnica y ELO.{hydration_suffix}"
        )
    elif zone == "RED_DELOAD":
        deload_factor = 0.80 if (recovery_score < 40.0 and low_sleep_or_stress) else 0.85
        next_weight = round_to_plate_increment(prescribed_weight_kg * deload_factor)
        next_reps = prescribed_reps
        rationale = (
            f"Recuperación comprometida ({recovery_score:.0f}%) y estrés elevado ({source_device}). "
            f"Redujimos el volumen prescrito para evitar fatiga del SNC.{hydration_suffix}"
        )
    elif zone == "GREEN_OVERLOAD" and actual_rpe <= prescribed_rpe and not low_hydration:
        next_weight = round_to_plate_increment(actual_weight_kg + overload_step)
        next_reps = prescribed_reps
        rationale = (
            f"Recuperación óptima ({recovery_score:.0f}% en {source_device}) y serie sólida. "
            f"Sobrecarga progresiva: +{overload_step:.1f} kg ({next_weight} kg)."
        )
    else:
        next_weight = round_to_plate_increment(actual_weight_kg)
        next_reps = prescribed_reps
        rationale = (
            f"Estabilidad mecánica verificada ({next_weight} kg x {next_reps} reps "
            f"@ RPE {actual_rpe}). Mantén la carga prescrita.{hydration_suffix}"
        )

    max_safe = round_to_plate_increment(historical_1rm_kg * 0.95)
    guardrail_hit = False
    if historical_1rm_kg > 0 and next_weight > max_safe:
        next_weight = max_safe
        guardrail_hit = True

    items = [
        PrescribedSetItem(
            set_number=s_num,
            prescribed_weight_kg=next_weight,
            prescribed_reps=next_reps,
            prescribed_rpe=target_rpe,
            rest_seconds=180 if target_rpe >= 8.0 else 120,
        )
        for s_num in remaining_sets
    ]

    return AdaptivePrescriptionResponse(
        readiness_zone=zone,
        adjustment_rationale=rationale,
        safety_guardrail_triggered=guardrail_hit,
        updated_sets=items,
    )


async def generate_adaptive_prescription(
    payload: dict[str, Any],
) -> AdaptivePrescriptionResponse:
    """
    Invoca a Gemini 2.5 Flash con `temperature=0.2` y `response_schema` para
    recalcular las series restantes en tiempo real, aplicando guardrails post-inferencia.
    """
    settings = get_settings()
    athlete = payload["athlete_context"]
    wearable = athlete["wearable_recovery"]
    exercise = payload["exercise_context"]
    feedback = payload["last_completed_set_feedback"]
    remaining = payload["remaining_sets_to_recalculate"]

    if not remaining:
        zone = (
            "RED_DELOAD"
            if wearable["recovery_score"] < 40.0
            else ("GREEN_OVERLOAD" if wearable["recovery_score"] > 80.0 else "YELLOW_MAINTENANCE")
        )
        return AdaptivePrescriptionResponse(
            readiness_zone=zone,
            adjustment_rationale="Ejercicio completado. Todas las series de este bloque han finalizado.",
            safety_guardrail_triggered=False,
            updated_sets=[],
        )

    if not settings.GEMINI_API_KEY:
        return deterministic_fallback_prescription(
            recovery_score=wearable["recovery_score"],
            historical_1rm_kg=exercise["historical_1rm_kg"],
            completed_binary=feedback["completed_binary_ui"],
            prescribed_weight_kg=feedback["prescribed_weight_kg"],
            prescribed_reps=feedback["prescribed_reps"],
            prescribed_rpe=feedback["prescribed_rpe"],
            actual_weight_kg=feedback["actual_weight_kg"],
            actual_reps=feedback["actual_reps"],
            actual_rpe=feedback["actual_rpe"],
            remaining_sets=remaining,
            unit_system=athlete.get("unit_system", "KG"),
            sleep_efficiency_pct=wearable.get("sleep_efficiency_pct", 85.0),
            hydration_ml_today=athlete.get("hydration_ml_today", 2000),
            source_device=wearable.get("source_device", "WHOOP"),
        )

    try:
        from google import genai
        from google.genai import types

        client = genai.Client(api_key=settings.GEMINI_API_KEY)
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=json.dumps(payload, ensure_ascii=False),
            config=types.GenerateContentConfig(
                system_instruction=COACH_ADAPTIVE_SYSTEM_PROMPT,
                temperature=0.2,
                top_p=0.8,
                top_k=20,
                max_output_tokens=1024,
                response_mime_type="application/json",
                response_schema=AdaptivePrescriptionResponse,
            ),
        )
        parsed = AdaptivePrescriptionResponse.model_validate_json(response.text)

        # Guardrail biomecánico post-inferencia (máx 95% 1RM y múltiplos de 2.5 kg)
        max_safe = round_to_plate_increment(exercise["historical_1rm_kg"] * 0.95)
        guardrail_triggered = parsed.safety_guardrail_triggered
        sanitized: list[PrescribedSetItem] = []

        for item in parsed.updated_sets:
            w = round_to_plate_increment(item.prescribed_weight_kg)
            if exercise["historical_1rm_kg"] > 0 and w > max_safe:
                w = max_safe
                guardrail_triggered = True
            sanitized.append(
                PrescribedSetItem(
                    set_number=item.set_number,
                    prescribed_weight_kg=w,
                    prescribed_reps=item.prescribed_reps,
                    prescribed_rpe=item.prescribed_rpe,
                    rest_seconds=item.rest_seconds,
                )
            )

        return AdaptivePrescriptionResponse(
            readiness_zone=parsed.readiness_zone,
            adjustment_rationale=parsed.adjustment_rationale,
            safety_guardrail_triggered=guardrail_triggered,
            updated_sets=sanitized,
        )
    except Exception as exc:
        logger.warning(
            "Fallback al motor determinista local tras error en Gemini API: %s", exc
        )
        return deterministic_fallback_prescription(
            recovery_score=wearable["recovery_score"],
            historical_1rm_kg=exercise["historical_1rm_kg"],
            completed_binary=feedback["completed_binary_ui"],
            prescribed_weight_kg=feedback["prescribed_weight_kg"],
            prescribed_reps=feedback["prescribed_reps"],
            prescribed_rpe=feedback["prescribed_rpe"],
            actual_weight_kg=feedback["actual_weight_kg"],
            actual_reps=feedback["actual_reps"],
            actual_rpe=feedback["actual_rpe"],
            remaining_sets=remaining,
            unit_system=athlete.get("unit_system", "KG"),
            sleep_efficiency_pct=wearable.get("sleep_efficiency_pct", 85.0),
            hydration_ml_today=athlete.get("hydration_ml_today", 2000),
            source_device=wearable.get("source_device", "WHOOP"),
        )
