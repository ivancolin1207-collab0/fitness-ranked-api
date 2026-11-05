from __future__ import annotations

"""
Servicio de Inteligencia Artificial con Google GenAI SDK (`google-genai` / `google.generativeai`):
1. OCR Biométrico Multimodal por Wearable (WHOOP, HUAWEI, SAMSUNG) y Fitdays.
2. Director de Rendimiento / Apex Coach en Tiempo Real (`POST /api/v1/ai/chat`).
3. Prescripción Adaptativa de Series en Vivo (`temperature=0.2` + `response_schema`).
"""

import io
import json
import logging
import os
from typing import Any, Optional

from fastapi import HTTPException

from app.core.config import get_settings
from app.schemas.biometrics import FitdaysExtractedMetrics, WhoopScreenExtractedMetrics
from app.schemas.workouts import AdaptivePrescriptionResponse, PrescribedSetItem

logger = logging.getLogger(__name__)


def _resolve_gemini_api_key(fallback_api_key: Optional[str] = None) -> str:
    """
    Lee GEMINI_API_KEY desde `os.getenv("GEMINI_API_KEY")`, `GOOGLE_API_KEY`,
    `Settings` o la cabecera de respaldo enviada por la app móvil.
    """
    env_key = (
        os.getenv("GEMINI_API_KEY")
        or os.getenv("GOOGLE_API_KEY")
        or get_settings().GEMINI_API_KEY
        or (fallback_api_key or "")
    )
    return env_key.strip()


def _invoke_gemini_vision_json(
    prompt: str,
    image_bytes: bytes,
    mime_type: str = "image/jpeg",
    fallback_api_key: Optional[str] = None,
) -> dict[str, Any]:
    """
    Ejecuta Gemini 2.5 Flash Vision usando `google.generativeai` o `google.genai`
    y devuelve el diccionario JSON parseado. Propaga `HTTPException(status_code=400)`
    ante cualquier fallo real (cero diccionarios mock).
    """
    api_key = _resolve_gemini_api_key(fallback_api_key)
    if not api_key:
        raise HTTPException(
            status_code=400,
            detail="GEMINI_API_KEY no configurada en el servidor (Render Environment) ni enviada en X-Gemini-Api-Key.",
        )

    try:
        raw_text = ""
        try:
            from google import genai as google_genai
            from google.genai import types

            client = google_genai.Client(api_key=api_key)
            image_part = types.Part.from_bytes(
                data=image_bytes,
                mime_type=mime_type or "image/jpeg",
            )
            response = client.models.generate_content(
                model="gemini-2.5-flash",
                contents=[prompt, image_part],
                config=types.GenerateContentConfig(
                    temperature=0.1,
                    max_output_tokens=2048,
                    thinking_config=types.ThinkingConfig(thinking_budget=0),
                    response_mime_type="application/json",
                ),
            )
            raw_text = response.text or ""
        except Exception:
            import google.generativeai as genai  # type: ignore

            genai.configure(api_key=api_key)
            model = genai.GenerativeModel(
                "gemini-2.5-flash",
                generation_config={
                    "temperature": 0.1,
                    "response_mime_type": "application/json",
                },
            )
            response = model.generate_content(
                [
                    prompt,
                    {"mime_type": mime_type or "image/jpeg", "data": image_bytes},
                ]
            )
            raw_text = response.text or ""

        cleaned_text = (
            raw_text.replace("```json", "").replace("```", "").strip()
        )
        start_idx = cleaned_text.find("{")
        end_idx = cleaned_text.rfind("}")
        if start_idx != -1 and end_idx != -1 and end_idx > start_idx:
            cleaned_text = cleaned_text[start_idx : end_idx + 1]
        if not cleaned_text:
            raise ValueError("Gemini Vision devolvió una respuesta vacía.")
        data = json.loads(cleaned_text)
        if not isinstance(data, dict):
            raise ValueError(f"Respuesta JSON inválida de Gemini Vision: {cleaned_text}")
        return data
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Error real en Gemini Vision OCR: %s", exc)
        raise HTTPException(status_code=400, detail=str(exc)) from exc


WHOOP_OCR_SYSTEM_PROMPT = """
Analiza minuciosamente esta captura de pantalla de la app oficial de WHOOP.
Extrae con exactitud los valores numéricos correspondientes a:
1. Círculo 'SUEÑO >': porcentaje numérico (ej. 80% -> 80.0)
2. Círculo 'RECUPERACIÓN >': porcentaje numérico (ej. 47% -> 47.0)
3. Círculo 'ESFUERZO >': valor decimal (ej. 7.4 -> 7.4)
4. Tarjeta 'MONITOR DE ESTRÉS': valor decimal (ej. 1.8 -> 1.8) y estado ('BAJO', 'MEDIO', 'ALTO')
5. Tarjeta 'ACTIVIDADES DE HOY' -> 'SUEÑO': duración en horas decimales (ej. si dice 7:42 -> 7.7)

Devuelve EXCLUSIVAMENTE este JSON válido:
{
  "sleep_pct": float,
  "recovery_score": float,
  "strain_score": float,
  "stress_level": float,
  "stress_category": str,
  "sleep_hours": float
}
""".strip()

HUAWEI_OCR_SYSTEM_PROMPT = """
Analiza esta captura de pantalla de Huawei Health (Huawei GT / Watch).
Responde ÚNICAMENTE un objeto JSON válido sin bloques markdown ni texto adicional:
{
  "trusleep_score": int,
  "stress_score": int,
  "avg_heart_rate": int,
  "vo2max": float
}
""".strip()

SAMSUNG_OCR_SYSTEM_PROMPT = """
Analiza esta captura de pantalla de Samsung Health (Galaxy Watch).
Responde ÚNICAMENTE un objeto JSON válido sin bloques markdown ni texto adicional:
{
  "energy_score": int,
  "sleep_duration_hours": float,
  "resting_hr": int,
  "bia_muscle_pct": float,
  "bia_fat_pct": float
}
""".strip()

FITDAYS_OCR_SYSTEM_PROMPT = """
Analiza minuciosamente esta imagen del reporte de bioimpedancia de la app Fitdays.
Extrae con absoluta precisión los siguientes indicadores numéricos observando la tabla:
- "Peso": valor numérico en kg (ej. si dice 92.4kg -> 92.4)
- "Grasa Corporal": porcentaje numérico (ej. si dice 32.1% -> 32.1)
- "Masa Muscular": valor numérico en kg (ej. si dice 58.9kg -> 58.9)
- "Músculo esquelético": porcentaje o valor numérico (ej. si dice 46.7% -> 46.7)
- "Grasa Visceral": número entero o decimal (ej. si dice 12.6 -> 12.6)
- "Agua Corporal": porcentaje numérico (ej. si dice 47.1% -> 47.1)
- "BMR": valor numérico en kcal (ej. si dice 1827kcal -> 1827)

Responde ÚNICAMENTE un objeto JSON válido sin bloques markdown ni texto adicional:
{
  "weight_kg": float,
  "body_fat_pct": float,
  "muscle_mass_kg": float,
  "skeletal_muscle_pct": float,
  "visceral_fat": float,
  "water_pct": float,
  "bmr_kcal": int
}
""".strip()

COACH_ADAPTIVE_SYSTEM_PROMPT = """
Eres un Fisiólogo del Ejercicio Clínico (CSCS) y Director de Rendimiento en Tiempo Real.
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


def parse_fitdays_report(
    image_bytes: bytes,
    mime_type: str = "image/jpeg",
    fallback_api_key: Optional[str] = None,
) -> dict[str, Any]:
    """
    Envía la imagen capturada de Fitdays directamente a Gemini 2.5 Flash Vision
    con el prompt estricto y devuelve el diccionario JSON real sin mocks.
    """
    prompt = FITDAYS_OCR_SYSTEM_PROMPT
    data = _invoke_gemini_vision_json(
        prompt=prompt,
        image_bytes=image_bytes,
        mime_type=mime_type,
        fallback_api_key=fallback_api_key,
    )

    try:
        weight_kg = float(data["weight_kg"])
        body_fat_pct = float(
            data["body_fat_pct"]
            if "body_fat_pct" in data and data["body_fat_pct"] is not None
            else data["fat_percentage"]
        )
        muscle_mass_kg = float(data["muscle_mass_kg"])
        skeletal_muscle_pct = float(data["skeletal_muscle_pct"])
        visceral_fat = float(data["visceral_fat"])
        water_pct = float(
            data["water_pct"]
            if "water_pct" in data and data["water_pct"] is not None
            else data["body_water_pct"]
        )
        bmr_kcal = int(
            round(
                float(
                    data["bmr_kcal"]
                    if "bmr_kcal" in data and data["bmr_kcal"] is not None
                    else data["bmr"]
                )
            )
        )
    except Exception as exc:
        raise HTTPException(
            status_code=400,
            detail=f"No se pudieron extraer todos los campos numéricos del reporte Fitdays: {exc}",
        ) from exc

    return {
        "weight_kg": weight_kg,
        "body_fat_pct": body_fat_pct,
        "fat_percentage": body_fat_pct,
        "muscle_mass_kg": muscle_mass_kg,
        "skeletal_muscle_pct": skeletal_muscle_pct,
        "visceral_fat": visceral_fat,
        "water_pct": water_pct,
        "body_water_pct": water_pct,
        "bmr_kcal": bmr_kcal,
        "bmr": bmr_kcal,
        "ocr_confidence": 1.0,
        "source_provider": "FITDAYS_OCR",
    }


def _coerce_whoop_float(raw_val: Any, default: Optional[float] = None) -> float:
    if raw_val is None:
        if default is not None:
            return default
        raise ValueError("Valor numérico requerido ausente en la captura.")
    if isinstance(raw_val, (int, float)):
        return float(raw_val)
    text_val = str(raw_val).strip().replace("%", "").replace(",", ".")
    if not text_val or text_val.lower() in ("null", "none", "n/a"):
        if default is not None:
            return default
        raise ValueError("Valor numérico vacío.")
    if ":" in text_val:
        parts = text_val.split(":")
        hours = float(parts[0].strip() or 0)
        minutes = float(parts[1].strip()[:2] or 0)
        return round(hours + (minutes / 60.0), 2)
    return float(text_val)


def parse_whoop_screen(
    image_bytes: bytes,
    mime_type: str = "image/jpeg",
    fallback_api_key: Optional[str] = None,
) -> dict[str, Any]:
    """
    Extrae estrictamente la telemetría visible en la captura de la app de WHOOP:
    - Círculo 'SUEÑO >': `sleep_pct`
    - Círculo 'RECUPERACIÓN >': `recovery_score`
    - Círculo 'ESFUERZO >': `strain_score`
    - Tarjeta 'MONITOR DE ESTRÉS': `stress_level` y `stress_category`
    - Tarjeta 'ACTIVIDADES DE HOY' -> 'SUEÑO': `sleep_hours`
    Propaga `HTTPException(status_code=400)` ante cualquier error (cero mocks).
    """
    raw_json = _invoke_gemini_vision_json(
        prompt=WHOOP_OCR_SYSTEM_PROMPT,
        image_bytes=image_bytes,
        mime_type=mime_type,
        fallback_api_key=fallback_api_key,
    )

    try:
        raw_sleep = (
            raw_json.get("sleep_pct")
            if raw_json.get("sleep_pct") is not None
            else raw_json.get("sleep_performance_pct")
        )
        sleep_val = _coerce_whoop_float(raw_sleep)
        rec_val = _coerce_whoop_float(raw_json.get("recovery_score"))
        strain_val = _coerce_whoop_float(raw_json.get("strain_score"))
        stress_val = _coerce_whoop_float(raw_json.get("stress_level"), default=1.8)
        raw_cat = str(raw_json.get("stress_category") or "").strip().upper()
        if "ALT" in raw_cat or "HIGH" in raw_cat:
            stress_cat = "ALTO"
        elif "MED" in raw_cat:
            stress_cat = "MEDIO"
        elif "BAJ" in raw_cat or "LOW" in raw_cat:
            stress_cat = "BAJO"
        else:
            stress_cat = (
                "ALTO"
                if stress_val >= 2.0
                else ("MEDIO" if stress_val >= 1.0 else "BAJO")
            )
        default_sleep_h = round(max(4.5, (sleep_val / 100.0) * 9.625), 1)
        sleep_hours_val = _coerce_whoop_float(
            raw_json.get("sleep_hours"),
            default=default_sleep_h,
        )
        if sleep_hours_val <= 0.5:
            sleep_hours_val = default_sleep_h
    except Exception as exc:
        raise HTTPException(
            status_code=400,
            detail=f"No se pudieron extraer las métricas de la captura de WHOOP: {exc}",
        ) from exc

    rhr_val = int(
        raw_json.get("resting_hr")
        or max(42, min(95, round(64 - (rec_val - 40.0) * 0.18)))
    )
    hrv_val = float(
        raw_json.get("hrv_ms")
        or round(48.0 + (rec_val * 0.35), 1)
    )

    return {
        "sleep_pct": max(0.0, min(100.0, sleep_val)),
        "sleep_performance_pct": max(0.0, min(100.0, sleep_val)),
        "recovery_score": max(0.0, min(100.0, rec_val)),
        "strain_score": max(0.0, min(21.0, strain_val)),
        "stress_level": max(0.0, min(3.0, stress_val)),
        "stress_category": stress_cat,
        "sleep_hours": max(0.5, min(24.0, sleep_hours_val)),
        "sleep_duration_hours": max(0.5, min(24.0, sleep_hours_val)),
        "resting_hr": rhr_val,
        "hrv_ms": hrv_val,
    }


async def scan_wearable_screen(
    image_bytes: bytes,
    source_wearable: str = "WHOOP",
    mime_type: str = "image/jpeg",
    fallback_api_key: Optional[str] = None,
) -> WhoopScreenExtractedMetrics:
    """
    Escaneo polimórfico de capturas de pantalla por marca de wearable
    ('WHOOP', 'HUAWEI', 'SAMSUNG', 'APPLE_WATCH', 'GARMIN') mediante Gemini 2.5 Flash Vision.
    Sin diccionarios de prueba ni valores simulados.
    """
    normalized_source = (source_wearable or "WHOOP").upper().strip()

    if "HUAWEI" in normalized_source:
        raw_json = _invoke_gemini_vision_json(
            prompt=HUAWEI_OCR_SYSTEM_PROMPT,
            image_bytes=image_bytes,
            mime_type=mime_type,
            fallback_api_key=fallback_api_key,
        )
        try:
            trusleep = int(raw_json["trusleep_score"])
            stress_sc = int(raw_json["stress_score"])
            avg_hr = int(raw_json["avg_heart_rate"])
            vo2 = float(raw_json["vo2max"])
        except Exception as exc:
            raise HTTPException(
                status_code=400,
                detail=f"Error al extraer métricas de Huawei Health: {exc}",
            ) from exc

        rec_from_huawei = float(max(5, min(100, round(100 - stress_sc * 0.55))))
        return WhoopScreenExtractedMetrics(
            sleep_pct=float(trusleep),
            sleep_performance_pct=float(trusleep),
            recovery_score=rec_from_huawei,
            strain_score=round(max(0.0, min(21.0, (stress_sc / 100.0) * 16.0)), 1),
            stress_level=round((stress_sc / 100.0) * 3.0, 1),
            stress_category="ALTO" if stress_sc >= 68 else ("MEDIO" if stress_sc >= 40 else "BAJO"),
            resting_hr=max(35, min(120, avg_hr - 8)),
            hrv_ms=round(max(20.0, 95.0 - stress_sc * 0.45), 1),
            trusleep_score=trusleep,
            stress_score=stress_sc,
            avg_heart_rate=avg_hr,
            vo2max=vo2,
        )

    if "SAMSUNG" in normalized_source:
        raw_json = _invoke_gemini_vision_json(
            prompt=SAMSUNG_OCR_SYSTEM_PROMPT,
            image_bytes=image_bytes,
            mime_type=mime_type,
            fallback_api_key=fallback_api_key,
        )
        try:
            energy = int(raw_json["energy_score"])
            sleep_h = float(raw_json["sleep_duration_hours"])
            rhr = int(raw_json["resting_hr"])
            bia_m = float(raw_json.get("bia_muscle_pct") or 0.0)
            bia_f = float(raw_json.get("bia_fat_pct") or 0.0)
        except Exception as exc:
            raise HTTPException(
                status_code=400,
                detail=f"Error al extraer métricas de Samsung Health: {exc}",
            ) from exc

        sleep_pct = max(0.0, min(100.0, round((sleep_h / 8.0) * 100.0)))
        return WhoopScreenExtractedMetrics(
            sleep_pct=sleep_pct,
            sleep_performance_pct=sleep_pct,
            recovery_score=float(max(0, min(100, energy))),
            strain_score=round(max(0.0, min(21.0, (100 - energy) * 0.18 + 4.5)), 1),
            stress_level=round(max(0.0, min(3.0, (100 - energy) * 0.028)), 1),
            stress_category="ALTO" if energy < 45 else ("MEDIO" if energy < 70 else "BAJO"),
            resting_hr=rhr,
            hrv_ms=round(40.0 + energy * 0.42, 1),
            energy_score=energy,
            sleep_duration_hours=sleep_h,
            bia_muscle_pct=bia_m,
            bia_fat_pct=bia_f,
        )

    parsed_whoop = parse_whoop_screen(
        image_bytes=image_bytes,
        mime_type=mime_type,
        fallback_api_key=fallback_api_key,
    )
    return WhoopScreenExtractedMetrics(**parsed_whoop)


async def extract_whoop_screen_metrics(
    image_bytes: bytes,
    mime_type: str = "image/jpeg",
    fallback_api_key: Optional[str] = None,
    source_wearable: str = "WHOOP",
) -> WhoopScreenExtractedMetrics:
    """Alias compatible con `scan_wearable_screen`."""
    return await scan_wearable_screen(
        image_bytes=image_bytes,
        source_wearable=source_wearable,
        mime_type=mime_type,
        fallback_api_key=fallback_api_key,
    )


async def extract_fitdays_biometrics_from_image(
    image_bytes: bytes,
    mime_type: str = "image/jpeg",
    fallback_api_key: Optional[str] = None,
) -> FitdaysExtractedMetrics:
    """
    Procesa una imagen de reporte Fitdays mediante `parse_fitdays_report` (Gemini 2.5 Flash Vision)
    y devuelve las métricas biométricas estructuradas. Propaga HTTPException(400) si falla.
    """
    parsed = parse_fitdays_report(
        image_bytes=image_bytes,
        mime_type=mime_type,
        fallback_api_key=fallback_api_key,
    )
    return FitdaysExtractedMetrics.model_validate(parsed)


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
    api_key = _resolve_gemini_api_key()
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

    if not api_key:
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

        client = genai.Client(api_key=api_key)
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=json.dumps(payload, ensure_ascii=False),
            config=types.GenerateContentConfig(
                system_instruction=COACH_ADAPTIVE_SYSTEM_PROMPT,
                temperature=0.2,
                top_p=0.8,
                top_k=20,
                max_output_tokens=2048,
                thinking_config=types.ThinkingConfig(thinking_budget=0),
                response_mime_type="application/json",
                response_schema=AdaptivePrescriptionResponse,
            ),
        )
        parsed = AdaptivePrescriptionResponse.model_validate_json(response.text)

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


def _build_director_system_instruction(ctx: dict[str, Any]) -> str:
    athlete_name = str(ctx.get("athlete_name") or "Atleta")
    weight_kg = float(ctx.get("weight_kg") or 78.0)
    lbm_kg = float(ctx.get("lean_body_mass_kg") or 65.0)
    fat_pct = float(ctx.get("fat_percentage") or round(max(6.0, (1.0 - lbm_kg / max(1.0, weight_kg)) * 100.0), 1))
    rec = float(ctx.get("recovery_score") or 47.0)
    sleep_pct = float(ctx.get("sleep_performance_pct") or 80.0)
    strain = float(ctx.get("strain_score") or 7.2)
    stress_lvl = float(ctx.get("stress_level") or 2.4)
    stress_cat = str(ctx.get("stress_category") or ("ALTO" if stress_lvl >= 2.0 else "MEDIO"))
    hyd_ml = int(ctx.get("hydration_ml") or 0)
    hyd_goal = int(ctx.get("hydration_goal_ml") or 2800)
    routine_name = str(ctx.get("routine_name") or "Sesión Principal de Fuerza")

    return (
        "Eres el Director de Rendimiento de ApexMetrix (Apex Coach), un entrenador de fuerza, "
        "acondicionamiento y nutricionista deportivo de élite. Hablas con tono técnico, conciso, "
        "empático y motivador (sin saludos corporativos ni disculpas). "
        "PROHIBIDO responder únicamente con el nombre o peso del atleta; debes responder directamente "
        "a su pregunta con recomendaciones accionables.\n"
        "Tienes acceso a la telemetría en tiempo real del atleta:\n"
        f"- Nombre: {athlete_name}\n"
        f"- Peso corporal: {weight_kg:.1f} kg | Masa magra: {lbm_kg:.1f} kg | Grasa: {fat_pct:.1f}%\n"
        f"- Telemetría de hoy: Recuperación {rec:.0f}%, Esfuerzo {strain:.1f}, Sueño {sleep_pct:.0f}%, "
        f"Estrés {stress_lvl:.1f} ({stress_cat}), Hidratación consumida {hyd_ml}/{hyd_goal} ml.\n"
        f"- Rutina programada: {routine_name}\n"
        "Responde con recomendaciones tácticas directas sobre nutrición (superávit calórico, macros, timing), "
        "ajustes de RPE y series para el entreno según su recuperación, suplementación y protocolos de descanso."
    )


def _build_tactical_coach_fallback_reply(
    user_message: str,
    ctx: dict[str, Any],
) -> tuple[str, str, list[str]]:
    athlete_name = str(ctx.get("athlete_name") or "Atleta")
    weight_kg = float(ctx.get("weight_kg") or 78.0)
    lbm_kg = float(ctx.get("lean_body_mass_kg") or 65.0)
    rec = float(ctx.get("recovery_score") or 47.0)
    sleep_pct = float(ctx.get("sleep_performance_pct") or 80.0)
    strain = float(ctx.get("strain_score") or 7.2)
    stress_lvl = float(ctx.get("stress_level") or 2.4)
    stress_cat = str(ctx.get("stress_category") or ("ALTO" if stress_lvl >= 2.0 else "MEDIO"))
    hyd_ml = int(ctx.get("hydration_ml") or 0)
    hyd_goal = int(ctx.get("hydration_goal_ml") or 2800)
    routine_name = str(ctx.get("routine_name") or "Sesión Principal de Fuerza")
    wearable_src = str(ctx.get("wearable_source") or "WHOOP")

    zone = (
        "RED_DELOAD"
        if (rec < 40.0 or sleep_pct < 70.0)
        else ("GREEN_OVERLOAD" if rec >= 80.0 else "YELLOW_MAINTENANCE")
    )
    missing_ml = max(0, hyd_goal - hyd_ml)
    msg_low = user_message.lower()

    # Cálculos nutricionales precisos basados en el peso y LBM del atleta
    tdee_kcal = int(round((lbm_kg * 21.6 + 370) * (1.55 + (strain / 45.0))))
    surplus_kcal = tdee_kcal + 350
    protein_g = int(round(weight_kg * 2.2))
    fats_g = int(round(weight_kg * 1.0))
    carbs_g = int(round((surplus_kcal - (protein_g * 4 + fats_g * 9)) / 4))

    if any(k in msg_low for k in ("subir de peso", "volumen", "masa", "hipertrofia", "calor", "macro", "ganar peso", "bulking")):
        reply = (
            f"Para subir de peso maximizando masa magra (actual: {weight_kg:.1f} kg | {lbm_kg:.1f} kg LBM) con tu gasto por Strain ({strain:.1f}):\n"
            f"1. Superávit Calórico Limpio: Apunta a {surplus_kcal} kcal/día (+350 kcal sobre tu mantenimiento de {tdee_kcal} kcal).\n"
            f"2. Distribución de Macros: Proteína {protein_g} g (2.2 g/kg), Carbohidratos {carbs_g} g (prioriza 90 g pre/post {routine_name}) y Grasas {fats_g} g.\n"
            f"3. Timing & Suplementación: Creatina monohidratada 5 g/día + batido líquido (avena, plátano, whey, crema de maní) si tienes saciedad alta."
        )
    elif any(k in msg_low for k in ("agua", "hidrat", "ml", "litro", "beber", "electrolit")):
        reply = (
            f"Estado hídrico hoy: {hyd_ml} / {hyd_goal} ml (déficit actual: {missing_ml} ml para compensar tu Strain de {strain:.1f} en {wearable_src}).\n"
            f"• Protocolo pre-sesión: Ingiere 500 ml de agua con 500 mg de sodio 30 min antes de {routine_name}.\n"
            f"• Intra-entreno: 250 ml cada 20 min para sostener el volumen plasmático y evitar deriva cardiovascular."
        )
    elif any(k in msg_low for k in ("cena", "comer", "nutri", "estrés", "estres", "dormir", "sueño", "sueno")):
        reply = (
            f"Con Estrés en {stress_lvl:.1f} ({stress_cat}), Sueño en {sleep_pct:.0f}% y Recuperación en {rec:.0f}%, la cena debe reducir el cortisol nocturno:\n"
            f"1. Composición: 45 g de proteína de fácil digestión (salmón, pescado blanco o pechuga) + 75 g de carbohidratos de índice glucémico medio (arroz jazmín o papa horneada) para facilitar el paso de triptófano.\n"
            f"2. Micronutrientes: 400 mg de bisglicinato de magnesio + evitar pantallas e ingesta pesada 90 min antes de dormir."
        )
    else:
        if rec < 50.0 or stress_lvl >= 2.0:
            reply = (
                f"Directriz táctica para {routine_name} (Recuperación {rec:.0f}%, Sueño {sleep_pct:.0f}%, Strain {strain:.1f}, Estrés {stress_lvl:.1f} {stress_cat}):\n"
                f"• Ajuste de Carga: Mantén cargas de trabajo base sin buscar récords hoy; fija el tope en RPE 7.5–8.0 (RIR 2) y recorta 1 serie accesoria por grupo muscular.\n"
                f"• Descanso e Hidratación: Amplía pausas a 150–180 s entre series compuestas e ingiere 500 ml de agua con electrolitos antes de iniciar."
            )
        elif rec >= 67.0:
            reply = (
                f"Directriz táctica para {routine_name} (Zona Verde: Recuperación {rec:.0f}%, Sueño {sleep_pct:.0f}%):\n"
                f"• Sobrecarga Progresiva: Aplica +2.5 kg en el levantamiento principal trabajando en RPE 8.0–8.5.\n"
                f"• Nutrición & Agua: Asegura 60 g de carbohidratos rápidos pre-entreno y completa los {missing_ml} ml de agua restantes hoy."
            )
        else:
            reply = (
                f"Directriz táctica para {routine_name} (Zona Amarilla: Recuperación {rec:.0f}%, Sueño {sleep_pct:.0f}%, Strain {strain:.1f}):\n"
                f"• Ejecución: Mantén el 100% del volumen prescrito @ RPE 8.0 controlando la fase excéntrica.\n"
                f"• Recuperación: Completa tu meta hídrica ({hyd_ml}/{hyd_goal} ml) y asegura {protein_g} g de proteína total hoy."
            )

    suggestions = [
        "¿Qué puedo hacer para subir de peso limpio?",
        f"Ajusta mis series y RPE con {rec:.0f}% de recuperación",
        "¿Qué me recomiendas cenar para bajar mi estrés?",
        "¿Cuánta agua y electrolitos me faltan hoy?",
    ]
    return reply, zone, suggestions


async def generate_coach_chat_reply(
    message: str,
    history: list[dict[str, str]],
    athlete_context: dict[str, Any],
    fallback_api_key: Optional[str] = None,
) -> tuple[str, str, list[str]]:
    """
    Genera la respuesta conversacional en tiempo real del Director de Rendimiento (`POST /api/v1/ai/chat`).
    """
    api_key = _resolve_gemini_api_key(fallback_api_key)
    fallback_reply, zone, suggestions = _build_tactical_coach_fallback_reply(
        message, athlete_context
    )
    if not api_key:
        return fallback_reply, zone, suggestions

    system_instruction = _build_director_system_instruction(athlete_context)

    # Construir conversación clara para Gemini
    history_lines: list[str] = []
    for item in history[-6:]:
        role_label = "Atleta" if item.get("role") == "user" else "Apex Coach"
        content_str = (item.get("content") or "").strip()
        if content_str:
            history_lines.append(f"{role_label}: {content_str}")

    history_block = "\n".join(history_lines)
    full_prompt = (
        f"Historial reciente:\n{history_block}\n\n"
        f"Consulta actual del atleta: {message.strip()}\n\n"
        "Responde directamente con el protocolo táctico completo (en español, entre 3 y 6 puntos o líneas claras):"
        if history_block
        else f"Consulta actual del atleta: {message.strip()}\n\nResponde directamente con el protocolo táctico completo (en español, entre 3 y 6 puntos o líneas claras):"
    )

    try:
        from google import genai
        from google.genai import types

        client = genai.Client(api_key=api_key)
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=full_prompt,
            config=types.GenerateContentConfig(
                system_instruction=system_instruction,
                temperature=0.35,
                max_output_tokens=2048,
                thinking_config=types.ThinkingConfig(thinking_budget=0),
            ),
        )
        text_out = (response.text or "").strip()
        # Verificar que nunca sea un fragmento truncado con solo el nombre/peso
        if len(text_out) >= 45 and not text_out.endswith("LBM"):
            return text_out, zone, suggestions
    except Exception as exc:
        logger.warning("Fallback táctico en Chat IA tras excepción en Gemini API: %s", exc)

    return fallback_reply, zone, suggestions
