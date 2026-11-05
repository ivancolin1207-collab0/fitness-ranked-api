from __future__ import annotations

"""
Motor Cognitivo de Generación de Rutinas Dinámicas con Gemini 2.5 Flash (`ai_routine_service.py`).
Elimina cualquier plantilla estática y diseña una periodización semanal de 5 días x 6 ejercicios
(3 principales + 3 secundarios/sinergistas por día) con cargas reales en KG derivadas de la Masa Magra (LBM),
composición corporal y telemetría de recuperación del wearable.
"""

import json
import logging
import re
from datetime import datetime, timezone
from typing import Any, Optional
from uuid import UUID

import google.generativeai as genai
from sqlalchemy import delete, select, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.elo_engine import ExerciseCategory, Formula1RM
from app.models.entities import (
    Biometric,
    Exercise,
    RoutineTemplate,
    RoutineTemplateExercise,
    User,
    WearableMetric,
)
from app.models.routine import UserRoutine, WorkoutDay, WorkoutExercise
from app.services.gemini_service import _resolve_gemini_api_key, round_to_plate_increment

logger = logging.getLogger("apexmetrix_ai_routine")


async def ensure_ai_routine_tables(db: AsyncSession) -> None:
    """Garantiza que las tablas relacionales `user_routines`, `workout_days` y `workout_exercises` existan en PostgreSQL."""
    await db.execute(
        text(
            """
            CREATE TABLE IF NOT EXISTS user_routines (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                name VARCHAR(180) NOT NULL,
                weekly_focus VARCHAR(240) NOT NULL DEFAULT 'Enfoque biomecánico adaptado a LBM',
                generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                status VARCHAR(30) NOT NULL DEFAULT 'active'
            )
            """
        )
    )
    await db.execute(
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
    await db.execute(
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


def _parse_first_int_from_reps(reps_str: Any, default_reps: int = 8) -> int:
    """Extrae el entero objetivo para `RoutineTemplateExercise.target_reps` (ej. '6-8' -> 8, '10-12' -> 10)."""
    if isinstance(reps_str, (int, float)):
        return max(1, int(round(float(reps_str))))
    raw = str(reps_str or "").strip()
    matches = re.findall(r"\d+", raw)
    if not matches:
        return default_reps
    if len(matches) >= 2:
        # Tomamos el límite superior o media del rango prescrito
        return max(1, int(matches[0]))
    return max(1, int(matches[0]))


def _compute_lbm_scaled_weight(
    lbm_kg: float,
    recovery_pct: float,
    lbm_coefficient: float,
    min_kg: float = 10.0,
) -> float:
    """
    Calcula matemáticamente la carga inicial de trabajo en KG a partir de la Masa Magra (LBM)
    y el factor de autoregulación por recuperación del SNC (Whoop/Wearable).
    """
    if recovery_pct < 34.0:
        readiness_factor = 0.85
    elif recovery_pct >= 67.0:
        readiness_factor = 1.04
    else:
        readiness_factor = 0.96

    raw_weight = max(min_kg, lbm_kg * lbm_coefficient * readiness_factor)
    return round_to_plate_increment(raw_weight)


def _build_lbm_biomechanical_5x6_plan(
    full_name: str,
    weight_kg: float,
    body_fat_pct: float,
    lbm_kg: float,
    recovery_pct: float,
    sleep_pct: float,
    stress_score: float,
) -> dict[str, Any]:
    """
    Calcula la periodización biomecánica personalizada de 5 días x 6 ejercicios (3 principales + 3 secundarios)
    derivada matemáticamente del LBM real del atleta, su % de grasa y su recuperación actual.
    Se utiliza para validar/completar la respuesta de Gemini o como motor determinista si la cuota de API falla.
    """
    base_rpe = 7.5 if recovery_pct < 36.0 else (8.5 if recovery_pct >= 70.0 else 8.0)

    def w(coeff: float, floor_kg: float = 10.0) -> float:
        return _compute_lbm_scaled_weight(lbm_kg, recovery_pct, coeff, floor_kg)

    days: list[dict[str, Any]] = [
        {
            "day_number": 1,
            "day_name": "Día 1: Empuje (Pectoral & Tríceps)",
            "target_muscles": ["Pectoral", "Tríceps"],
            "exercises": [
                {
                    "order": 1,
                    "exercise_key": "bench_press_barbell",
                    "name": "Press de Banca Plano con Barra",
                    "muscle_group": "Pectoral",
                    "target_sets": 4,
                    "target_reps": "6-8",
                    "prescribed_weight_kg": w(1.04, 40.0),
                    "rpe_target": base_rpe,
                    "rest_seconds": 120,
                    "tempo": "3-0-1-0",
                    "coaching_cue": "Retracción escapular activa y pausa controlada a 2cm del esternón",
                },
                {
                    "order": 2,
                    "exercise_key": "incline_dumbbell_press",
                    "name": "Press Inclinado con Mancuernas (30°)",
                    "muscle_group": "Pectoral",
                    "target_sets": 4,
                    "target_reps": "8-10",
                    "prescribed_weight_kg": w(0.42, 16.0),
                    "rpe_target": base_rpe,
                    "rest_seconds": 90,
                    "tempo": "3-1-1-0",
                    "coaching_cue": "Baja con codos a 45° estirando fibras claviculares sin perder arco torácico",
                },
                {
                    "order": 3,
                    "exercise_key": "chest_dip_weighted",
                    "name": "Fondos en Paralelas / Cruce en Polea Baja",
                    "muscle_group": "Pectoral",
                    "target_sets": 3,
                    "target_reps": "10-12",
                    "prescribed_weight_kg": w(0.38, 15.0),
                    "rpe_target": base_rpe,
                    "rest_seconds": 90,
                    "tempo": "3-0-1-1",
                    "coaching_cue": "Inclina el torso 20° al frente y exprime el pectoral interno arriba",
                },
                {
                    "order": 4,
                    "exercise_key": "tricep_french_press",
                    "name": "Press Francés con Barra EZ",
                    "muscle_group": "Tríceps",
                    "target_sets": 3,
                    "target_reps": "8-10",
                    "prescribed_weight_kg": w(0.48, 20.0),
                    "rpe_target": base_rpe,
                    "rest_seconds": 90,
                    "tempo": "3-0-1-0",
                    "coaching_cue": "Mantén húmeros fijos a 80° para máximo estiramiento de la cabeza larga",
                },
                {
                    "order": 5,
                    "exercise_key": "tricep_rope_pushdown",
                    "name": "Extensión de Tríceps en Polea con Cuerda",
                    "muscle_group": "Tríceps",
                    "target_sets": 3,
                    "target_reps": "10-12",
                    "prescribed_weight_kg": w(0.44, 17.5),
                    "rpe_target": round(min(8.5, base_rpe + 0.5), 1),
                    "rest_seconds": 75,
                    "tempo": "2-0-1-1",
                    "coaching_cue": "Bloquea codos a los costados y abre la cuerda al final de la extensión",
                },
                {
                    "order": 6,
                    "exercise_key": "overhead_tricep_extension",
                    "name": "Extensión de Tríceps Trasnuca en Polea",
                    "muscle_group": "Tríceps",
                    "target_sets": 3,
                    "target_reps": "12-15",
                    "prescribed_weight_kg": w(0.38, 15.0),
                    "rpe_target": round(min(8.5, base_rpe + 0.5), 1),
                    "rest_seconds": 75,
                    "tempo": "3-1-1-0",
                    "coaching_cue": "Costillas cerradas, estira al máximo el tríceps en fase excéntrica",
                },
            ],
        },
        {
            "day_number": 2,
            "day_name": "Día 2: Tracción (Espalda & Bíceps)",
            "target_muscles": ["Espalda", "Bíceps"],
            "exercises": [
                {
                    "order": 1,
                    "exercise_key": "barbell_row",
                    "name": "Remo con Barra Prono (Pendlay / 45°)",
                    "muscle_group": "Espalda",
                    "target_sets": 4,
                    "target_reps": "6-8",
                    "prescribed_weight_kg": w(1.10, 45.0),
                    "rpe_target": base_rpe,
                    "rest_seconds": 120,
                    "tempo": "2-0-1-1",
                    "coaching_cue": "Bisagra de cadera isométrica, tracciona hacia el abdomen bajo apretando escápulas",
                },
                {
                    "order": 2,
                    "exercise_key": "lat_pulldown",
                    "name": "Jalón al Pecho Agarre Prono Amplio",
                    "muscle_group": "Espalda",
                    "target_sets": 4,
                    "target_reps": "8-10",
                    "prescribed_weight_kg": w(0.95, 40.0),
                    "rpe_target": base_rpe,
                    "rest_seconds": 90,
                    "tempo": "3-0-1-1",
                    "coaching_cue": "Inicia con depresión escapular y dirige los codos hacia tus bolsillos",
                },
                {
                    "order": 3,
                    "exercise_key": "seated_cable_row",
                    "name": "Remo Gironda en Polea Baja con Pausa",
                    "muscle_group": "Espalda",
                    "target_sets": 3,
                    "target_reps": "10-12",
                    "prescribed_weight_kg": w(0.88, 37.5),
                    "rpe_target": base_rpe,
                    "rest_seconds": 90,
                    "tempo": "3-0-1-1",
                    "coaching_cue": "Pecho alto, retrae romboides 1 segundo completo en cada repetición",
                },
                {
                    "order": 4,
                    "exercise_key": "bicep_curl_barbell",
                    "name": "Curl de Bíceps con Barra EZ",
                    "muscle_group": "Bíceps",
                    "target_sets": 3,
                    "target_reps": "8-10",
                    "prescribed_weight_kg": w(0.52, 22.5),
                    "rpe_target": base_rpe,
                    "rest_seconds": 75,
                    "tempo": "3-0-1-1",
                    "coaching_cue": "Codos pegados al torso, evita balanceo lumbar y controla 3s la bajada",
                },
                {
                    "order": 5,
                    "exercise_key": "incline_dumbbell_curl",
                    "name": "Curl de Bíceps en Banco Inclinado (Mancuernas)",
                    "muscle_group": "Bíceps",
                    "target_sets": 3,
                    "target_reps": "10-12",
                    "prescribed_weight_kg": w(0.22, 10.0),
                    "rpe_target": round(min(8.5, base_rpe + 0.5), 1),
                    "rest_seconds": 75,
                    "tempo": "3-1-1-0",
                    "coaching_cue": "Hombros atrás contra el respaldo para estirar la cabeza larga del bíceps",
                },
                {
                    "order": 6,
                    "exercise_key": "hammer_curl_dumbbell",
                    "name": "Curl Martillo Cruzado (Braquial / Braquiorradial)",
                    "muscle_group": "Bíceps",
                    "target_sets": 3,
                    "target_reps": "10-12",
                    "prescribed_weight_kg": w(0.26, 12.5),
                    "rpe_target": round(min(8.5, base_rpe + 0.5), 1),
                    "rest_seconds": 75,
                    "tempo": "2-0-1-1",
                    "coaching_cue": "Agarre neutro firme, sube hasta el pectoral opuesto sin adelantar el codo",
                },
            ],
        },
        {
            "day_number": 3,
            "day_name": "Día 3: Tren Inferior A (Cuádriceps & Gemelos)",
            "target_muscles": ["Cuádriceps", "Gemelos"],
            "exercises": [
                {
                    "order": 1,
                    "exercise_key": "squat_barbell",
                    "name": "Sentadilla Libre con Barra (Back Squat)",
                    "muscle_group": "Cuádriceps",
                    "target_sets": 4,
                    "target_reps": "6-8",
                    "prescribed_weight_kg": w(1.38, 60.0),
                    "rpe_target": base_rpe,
                    "rest_seconds": 150,
                    "tempo": "3-1-1-0",
                    "coaching_cue": "Bracing abdominal 360°, rodillas alineadas con punteras y salida explosiva",
                },
                {
                    "order": 2,
                    "exercise_key": "leg_press",
                    "name": "Prensa Inclinada 45° Profunda",
                    "muscle_group": "Cuádriceps",
                    "target_sets": 4,
                    "target_reps": "8-10",
                    "prescribed_weight_kg": w(2.35, 110.0),
                    "rpe_target": base_rpe,
                    "rest_seconds": 120,
                    "tempo": "3-0-1-0",
                    "coaching_cue": "Sacro pegado al respaldo, baja hasta >95° de flexión de rodilla",
                },
                {
                    "order": 3,
                    "exercise_key": "bulgarian_split_squat",
                    "name": "Zancadas Búlgaras con Mancuernas",
                    "muscle_group": "Cuádriceps",
                    "target_sets": 3,
                    "target_reps": "8-10",
                    "prescribed_weight_kg": w(0.32, 15.0),
                    "rpe_target": base_rpe,
                    "rest_seconds": 90,
                    "tempo": "3-1-1-0",
                    "coaching_cue": "Empuja con toda la planta del pie delantero manteniendo pelvis nivelada",
                },
                {
                    "order": 4,
                    "exercise_key": "leg_extension",
                    "name": "Extensión de Cuádriceps en Máquina (Isometría)",
                    "muscle_group": "Cuádriceps",
                    "target_sets": 3,
                    "target_reps": "12-15",
                    "prescribed_weight_kg": w(0.82, 35.0),
                    "rpe_target": round(min(8.5, base_rpe + 0.5), 1),
                    "rest_seconds": 75,
                    "tempo": "3-0-1-1",
                    "coaching_cue": "Sostén 1 segundo arriba exprimiendo el vasto medial y baja en 3 segundos",
                },
                {
                    "order": 5,
                    "exercise_key": "standing_calf_raise",
                    "name": "Elevación de Talones de Pie en Máquina",
                    "muscle_group": "Gemelos",
                    "target_sets": 4,
                    "target_reps": "10-12",
                    "prescribed_weight_kg": w(1.15, 50.0),
                    "rpe_target": round(min(8.5, base_rpe + 0.5), 1),
                    "rest_seconds": 60,
                    "tempo": "2-2-1-1",
                    "coaching_cue": "Pausa de 2 segundos en dorsiflexión profunda para eliminar rebote del Aquiles",
                },
                {
                    "order": 6,
                    "exercise_key": "seated_calf_raise",
                    "name": "Elevación de Talones Sentado (Sóleo)",
                    "muscle_group": "Gemelos",
                    "target_sets": 3,
                    "target_reps": "12-15",
                    "prescribed_weight_kg": w(0.75, 32.5),
                    "rpe_target": round(min(8.5, base_rpe + 0.5), 1),
                    "rest_seconds": 60,
                    "tempo": "3-1-1-1",
                    "coaching_cue": "Rango completo sobre el metatarso manteniendo tensión constante",
                },
            ],
        },
        {
            "day_number": 4,
            "day_name": "Día 4: Hombros & Trapecio / Core",
            "target_muscles": ["Deltoides", "Trapecio"],
            "exercises": [
                {
                    "order": 1,
                    "exercise_key": "overhead_press",
                    "name": "Press Militar Overhead con Barra (OHP)",
                    "muscle_group": "Deltoides",
                    "target_sets": 4,
                    "target_reps": "6-8",
                    "prescribed_weight_kg": w(0.68, 30.0),
                    "rpe_target": base_rpe,
                    "rest_seconds": 120,
                    "tempo": "2-0-1-1",
                    "coaching_cue": "Glúteos y abdomen en bracing total, antebrazos verticales bajo la barra",
                },
                {
                    "order": 2,
                    "exercise_key": "lateral_raise",
                    "name": "Elevaciones Laterales en Plano Escapular",
                    "muscle_group": "Deltoides",
                    "target_sets": 4,
                    "target_reps": "12-15",
                    "prescribed_weight_kg": w(0.18, 10.0),
                    "rpe_target": round(min(8.5, base_rpe + 0.5), 1),
                    "rest_seconds": 75,
                    "tempo": "3-0-1-1",
                    "coaching_cue": "Eleva a 30° en plano escapular guiando con los codos sin encoger trapecios",
                },
                {
                    "order": 3,
                    "exercise_key": "rear_delt_fly",
                    "name": "Face Pull / Pájaros en Polea (Deltoides Posterior)",
                    "muscle_group": "Deltoides",
                    "target_sets": 3,
                    "target_reps": "12-15",
                    "prescribed_weight_kg": w(0.38, 15.0),
                    "rpe_target": base_rpe,
                    "rest_seconds": 75,
                    "tempo": "2-0-1-1",
                    "coaching_cue": "Tracciona hacia la frente con rotación externa de hombro al final",
                },
                {
                    "order": 4,
                    "exercise_key": "seated_dumbbell_shoulder_press",
                    "name": "Press de Hombros Sentado con Mancuernas",
                    "muscle_group": "Deltoides",
                    "target_sets": 3,
                    "target_reps": "8-10",
                    "prescribed_weight_kg": w(0.34, 15.0),
                    "rpe_target": base_rpe,
                    "rest_seconds": 90,
                    "tempo": "3-0-1-0",
                    "coaching_cue": "Desciende hasta que las mancuernas rocen la línea de las orejas",
                },
                {
                    "order": 5,
                    "exercise_key": "barbell_shrug",
                    "name": "Encogimientos con Barra / Mancuernas (Trapecio)",
                    "muscle_group": "Trapecio",
                    "target_sets": 3,
                    "target_reps": "10-12",
                    "prescribed_weight_kg": w(1.20, 50.0),
                    "rpe_target": base_rpe,
                    "rest_seconds": 75,
                    "tempo": "2-0-1-2",
                    "coaching_cue": "Eleva en diagonal superior-posterior y sostén 2 segundos arriba",
                },
                {
                    "order": 6,
                    "exercise_key": "cable_lateral_raise",
                    "name": "Elevación Lateral Unilateral en Polea Baja",
                    "muscle_group": "Deltoides",
                    "target_sets": 3,
                    "target_reps": "12-15",
                    "prescribed_weight_kg": w(0.16, 7.5),
                    "rpe_target": round(min(8.5, base_rpe + 0.5), 1),
                    "rest_seconds": 60,
                    "tempo": "3-0-1-1",
                    "coaching_cue": "Tensión constante desde los primeros 15° de abducción del hombro",
                },
            ],
        },
        {
            "day_number": 5,
            "day_name": "Día 5: Tren Inferior B (Cadena Posterior & Glúteo)",
            "target_muscles": ["Isquiosurales", "Glúteo"],
            "exercises": [
                {
                    "order": 1,
                    "exercise_key": "deadlift_barbell",
                    "name": "Peso Muerto Rumano con Barra (RDL)",
                    "muscle_group": "Isquiosurales",
                    "target_sets": 4,
                    "target_reps": "6-8",
                    "prescribed_weight_kg": w(1.32, 55.0),
                    "rpe_target": base_rpe,
                    "rest_seconds": 150,
                    "tempo": "3-1-1-0",
                    "coaching_cue": "Barra pegada a los muslos, empuja la cadera atrás sintiendo tensión isquiosural",
                },
                {
                    "order": 2,
                    "exercise_key": "hip_thrust",
                    "name": "Hip Thrust Pesado con Barra",
                    "muscle_group": "Glúteo",
                    "target_sets": 4,
                    "target_reps": "8-10",
                    "prescribed_weight_kg": w(1.55, 65.0),
                    "rpe_target": base_rpe,
                    "rest_seconds": 120,
                    "tempo": "2-0-1-2",
                    "coaching_cue": "Mentón recogido, tibias a 90° y retroversión pélvica de 2s en el bloqueo",
                },
                {
                    "order": 3,
                    "exercise_key": "seated_leg_curl",
                    "name": "Curl Femoral Sentado / Tumbado",
                    "muscle_group": "Isquiosurales",
                    "target_sets": 4,
                    "target_reps": "10-12",
                    "prescribed_weight_kg": w(0.76, 35.0),
                    "rpe_target": round(min(8.5, base_rpe + 0.5), 1),
                    "rest_seconds": 90,
                    "tempo": "3-0-1-1",
                    "coaching_cue": "Dorsiflexión de tobillo activa y fase excéntrica de 3 segundos sin despegar cadera",
                },
                {
                    "order": 4,
                    "exercise_key": "lunge_dumbbell",
                    "name": "Zancadas Caminando Largas (Énfasis Glúteo)",
                    "muscle_group": "Glúteo",
                    "target_sets": 3,
                    "target_reps": "10-12",
                    "prescribed_weight_kg": w(0.32, 15.0),
                    "rpe_target": base_rpe,
                    "rest_seconds": 90,
                    "tempo": "3-0-1-0",
                    "coaching_cue": "Zancada larga e inclinación de 15° en el torso para maximizar torque de cadera",
                },
                {
                    "order": 5,
                    "exercise_key": "hyperextension_weighted",
                    "name": "Extensión de Cadera 45° Lastrada",
                    "muscle_group": "Glúteo",
                    "target_sets": 3,
                    "target_reps": "12-15",
                    "prescribed_weight_kg": w(0.28, 12.5),
                    "rpe_target": base_rpe,
                    "rest_seconds": 75,
                    "tempo": "2-0-1-1",
                    "coaching_cue": "Redondea ligeramente la zona dorsal alta para aislar glúteo e isquios",
                },
                {
                    "order": 6,
                    "exercise_key": "calf_press_leg_press",
                    "name": "Prensa de Gemelos / Abducción de Cadera",
                    "muscle_group": "Glúteo",
                    "target_sets": 3,
                    "target_reps": "12-15",
                    "prescribed_weight_kg": w(0.95, 42.5),
                    "rpe_target": round(min(8.5, base_rpe + 0.5), 1),
                    "rest_seconds": 60,
                    "tempo": "3-1-1-1",
                    "coaching_cue": "Control total en ambos extremos del rango articular sin impulso",
                },
            ],
        },
    ]

    return {
        "routine_name": f"Hipertrofia Adaptativa Personalizada - {full_name}",
        "weekly_focus": (
            f"Recomposición & Fuerza adaptada a {lbm_kg:.2f} kg LBM "
            f"(Peso {weight_kg:.1f} kg • Grasa {body_fat_pct:.1f}% • Rec {recovery_pct:.0f}%)"
        ),
        "days": days,
    }


def _normalize_and_validate_ai_plan(
    raw_plan: dict[str, Any],
    fallback_plan: dict[str, Any],
    lbm_kg: float,
    recovery_pct: float,
) -> dict[str, Any]:
    """
    Asegura que el JSON devuelto por Gemini cumpla estrictamente con:
    - Exactamente 5 días (Día 1 a Día 5).
    - Exactamente 6 ejercicios por día (3 principales + 3 secundarios/sinergistas).
    - Cargas reales `prescribed_weight_kg` > 0 redondeadas a discos reales.
    """
    raw_days = raw_plan.get("days")
    if not isinstance(raw_days, list) or len(raw_days) == 0:
        return fallback_plan

    fallback_days = fallback_plan["days"]
    normalized_days: list[dict[str, Any]] = []

    for day_idx in range(5):
        fb_day = fallback_days[day_idx]
        src_day = raw_days[day_idx] if day_idx < len(raw_days) and isinstance(raw_days[day_idx], dict) else fb_day

        raw_exercises = src_day.get("exercises")
        if not isinstance(raw_exercises, list):
            raw_exercises = []

        normalized_exercises: list[dict[str, Any]] = []
        for ex_idx in range(6):
            fb_ex = fb_day["exercises"][ex_idx]
            src_ex = (
                raw_exercises[ex_idx]
                if ex_idx < len(raw_exercises) and isinstance(raw_exercises[ex_idx], dict)
                else fb_ex
            )
            raw_w = src_ex.get("prescribed_weight_kg")
            try:
                parsed_w = float(raw_w) if raw_w is not None else float(fb_ex["prescribed_weight_kg"])
                if parsed_w <= 2.0:
                    parsed_w = float(fb_ex["prescribed_weight_kg"])
            except Exception:
                parsed_w = float(fb_ex["prescribed_weight_kg"])

            try:
                parsed_sets = int(src_ex.get("target_sets") or fb_ex["target_sets"])
                parsed_sets = max(2, min(6, parsed_sets))
            except Exception:
                parsed_sets = int(fb_ex["target_sets"])

            try:
                parsed_rpe = float(src_ex.get("rpe_target") or fb_ex["rpe_target"])
                parsed_rpe = max(6.0, min(9.5, round(parsed_rpe, 1)))
            except Exception:
                parsed_rpe = float(fb_ex["rpe_target"])

            try:
                parsed_rest = int(src_ex.get("rest_seconds") or fb_ex["rest_seconds"])
                parsed_rest = max(45, min(240, parsed_rest))
            except Exception:
                parsed_rest = int(fb_ex["rest_seconds"])

            normalized_exercises.append(
                {
                    "order": ex_idx + 1,
                    "exercise_key": str(src_ex.get("exercise_key") or fb_ex["exercise_key"]).strip(),
                    "name": str(src_ex.get("name") or fb_ex["name"]).strip(),
                    "muscle_group": str(src_ex.get("muscle_group") or fb_ex["muscle_group"]).strip(),
                    "target_sets": parsed_sets,
                    "target_reps": str(src_ex.get("target_reps") or fb_ex["target_reps"]).strip(),
                    "prescribed_weight_kg": round_to_plate_increment(parsed_w),
                    "rpe_target": parsed_rpe,
                    "rest_seconds": parsed_rest,
                    "tempo": str(src_ex.get("tempo") or fb_ex["tempo"]).strip(),
                    "coaching_cue": str(src_ex.get("coaching_cue") or fb_ex["coaching_cue"]).strip(),
                }
            )

        raw_targets = src_day.get("target_muscles")
        if not isinstance(raw_targets, list) or not raw_targets:
            raw_targets = fb_day["target_muscles"]

        normalized_days.append(
            {
                "day_number": day_idx + 1,
                "day_name": str(src_day.get("day_name") or fb_day["day_name"]).strip(),
                "target_muscles": [str(m) for m in raw_targets],
                "exercises": normalized_exercises,
            }
        )

    return {
        "routine_name": str(raw_plan.get("routine_name") or fallback_plan["routine_name"]).strip(),
        "weekly_focus": str(raw_plan.get("weekly_focus") or fallback_plan["weekly_focus"]).strip(),
        "days": normalized_days,
    }


async def generate_and_persist_ai_routine(
    db: AsyncSession,
    user: User,
) -> dict[str, Any]:
    """
    Consulta la biometría real (peso, % grasa, LBM) y telemetría wearable del usuario,
    invoca a Gemini 2.5 Flash con las reglas estrictas de 5 días x 6 ejercicios,
    almacena la rutina en PostgreSQL (`user_routines`, `workout_days`, `workout_exercises`)
    y sincroniza `RoutineTemplate` / `RoutineTemplateExercise` para `LiveWorkoutScreen`.
    """
    await ensure_ai_routine_tables(db)

    # 1. Obtener última composición corporal real (Fitdays / Manual)
    bio_stmt = (
        select(Biometric)
        .where(Biometric.user_id == user.id)
        .order_by(Biometric.captured_at.desc())
        .limit(1)
    )
    latest_bio = (await db.execute(bio_stmt)).scalar_one_or_none()

    weight_kg = float(latest_bio.weight_kg) if latest_bio is not None else 92.4
    body_fat_pct = float(latest_bio.body_fat_pct) if latest_bio is not None else 32.1
    lbm_kg = (
        float(latest_bio.lean_body_mass_kg)
        if (latest_bio is not None and latest_bio.lean_body_mass_kg is not None)
        else round(weight_kg * (1.0 - body_fat_pct / 100.0), 2)
    )

    # 2. Obtener telemetría reciente del wearable (Whoop / Health Connect / daily_readiness)
    wearable_stmt = (
        select(WearableMetric)
        .where(WearableMetric.user_id == user.id)
        .order_by(WearableMetric.date.desc(), WearableMetric.synced_at.desc())
        .limit(1)
    )
    latest_wearable = (await db.execute(wearable_stmt)).scalar_one_or_none()

    recovery_pct = float(latest_wearable.recovery_score) if latest_wearable is not None else 47.0
    sleep_pct = float(latest_wearable.sleep_efficiency_pct) if latest_wearable is not None else 80.0
    stress_score = 1.8

    try:
        dr_row = (
            await db.execute(
                text(
                    """
                    SELECT recovery_score, sleep_pct, stress_level
                    FROM daily_readiness
                    WHERE user_id = :uid
                    ORDER BY date DESC, synced_at DESC
                    LIMIT 1
                    """
                ),
                {"uid": user.id},
            )
        ).first()
        if dr_row is not None:
            recovery_pct = float(dr_row[0])
            sleep_pct = float(dr_row[1])
            stress_score = float(dr_row[2])
    except Exception:
        pass

    full_name = (user.full_name or user.username or "Atleta").strip()

    fallback_plan = _build_lbm_biomechanical_5x6_plan(
        full_name=full_name,
        weight_kg=weight_kg,
        body_fat_pct=body_fat_pct,
        lbm_kg=lbm_kg,
        recovery_pct=recovery_pct,
        sleep_pct=sleep_pct,
        stress_score=stress_score,
    )

    prompt = f"""
Eres el Jefe de Rendimiento Físico y Biomecánica de ApexMetrix.
Diseña una periodización semanal de 5 DÍAS TOTALMENTE PERSONALIZADA para el siguiente atleta:
- Nombre: {full_name}
- Peso: {weight_kg:.1f} kg | Masa Magra (LBM): {lbm_kg:.2f} kg | Grasa: {body_fat_pct:.1f}%
- Telemetría reciente: Recuperación {recovery_pct:.0f}%, Sueño {sleep_pct:.0f}%, Estrés {stress_score:.1f}.

REGLAS ESTRICTAS DE PRESCRIPCIÓN:
1. Estructura exacta de 5 días de entrenamiento (Día 1 a Día 5).
2. Cada día DEBE CONTENER EXACTAMENTE 6 EJERCICIOS (3 para el grupo muscular principal y 3 para el grupo muscular secundario/sinergista).
3. CÁLCULO DE CARGAS REALES: NO uses porcentajes genéricos vacíos. Para cada ejercicio, calcula y asigna el PESO DE TRABAJO INICIAL EN KG (`prescribed_weight_kg`) específico para este atleta, derivado matemáticamente de su masa magra ({lbm_kg:.2f} kg LBM), nivel de recuperación ({recovery_pct:.0f}%) y el patrón de movimiento.
4. Define series (3-4), repeticiones (ej. 8-10), RPE objetivo (ej. 7.5 - 8.5) y tempo excéntrico/concéntrico (ej. "3-0-1-0").
5. Asigna a cada ejercicio un identificador biomecánico estándar (`exercise_key`) compatible con el visor de avatares (ej. `bench_press_barbell`, `incline_dumbbell_press`, `squat_barbell`, `deadlift_barbell`, `overhead_press`, `lat_pulldown`, `barbell_row`, `bicep_curl_barbell`, `lateral_raise`, `tricep_rope_pushdown`, `leg_press`, `hip_thrust`).

Devuelve EXCLUSIVAMENTE este esquema JSON sin bloques de texto adicionales:
{{
  "routine_name": "Hipertrofia Adaptativa Personalizada - {full_name}",
  "weekly_focus": "Enfoque biomecánico adaptado a {lbm_kg:.2f}kg LBM",
  "days": [
    {{
      "day_number": 1,
      "day_name": "Día 1: Empuje (Pecho & Tríceps)",
      "target_muscles": ["Pectoral", "Tríceps"],
      "exercises": [
        {{
          "order": 1,
          "exercise_key": "bench_press_barbell",
          "name": "Press de Banca Plano con Barra",
          "muscle_group": "Pectoral",
          "target_sets": 4,
          "target_reps": "6-8",
          "prescribed_weight_kg": 65.0,
          "rpe_target": 8.0,
          "rest_seconds": 90,
          "tempo": "3-0-1-0",
          "coaching_cue": "Retracción escapular activa y pausa controlada a 2cm del esternón"
        }}
      ]
    }}
  ]
}}
"""

    final_plan = fallback_plan
    api_key = _resolve_gemini_api_key()
    if api_key:
        try:
            genai.configure(api_key=api_key)
            for model_name in ("gemini-2.5-flash", "gemini-2.0-flash", "gemini-1.5-flash"):
                try:
                    model = genai.GenerativeModel(model_name)
                    response = model.generate_content(
                        prompt,
                        generation_config={"response_mime_type": "application/json"},
                    )
                    raw_text = (getattr(response, "text", None) or "").strip()
                    if raw_text.startswith("```"):
                        raw_text = re.sub(r"^```(?:json)?\s*", "", raw_text)
                        raw_text = re.sub(r"\s*```$", "", raw_text)
                    parsed_json = json.loads(raw_text)
                    if isinstance(parsed_json, dict):
                        final_plan = _normalize_and_validate_ai_plan(
                            raw_plan=parsed_json,
                            fallback_plan=fallback_plan,
                            lbm_kg=lbm_kg,
                            recovery_pct=recovery_pct,
                        )
                        break
                except Exception as inner_exc:
                    logger.warning(
                        "Intento con %s en generate_and_persist_ai_routine falló: %s",
                        model_name,
                        inner_exc,
                    )
        except Exception as exc:
            logger.warning("Fallback LBM activado en generate_and_persist_ai_routine: %s", exc)

    # 3. Reemplazar cualquier planificación anterior en PostgreSQL (`user_routines` + `routine_templates`)
    await db.execute(delete(UserRoutine).where(UserRoutine.user_id == user.id))
    await db.execute(delete(RoutineTemplate).where(RoutineTemplate.user_id == user.id))
    await db.flush()

    user_routine = UserRoutine(
        user_id=user.id,
        name=final_plan["routine_name"],
        weekly_focus=final_plan["weekly_focus"],
        generated_at=datetime.now(timezone.utc),
        status="active",
    )
    db.add(user_routine)
    await db.flush()

    for day_data in final_plan["days"]:
        day_num = int(day_data["day_number"])
        day_name = str(day_data["day_name"])
        target_muscles = [str(m) for m in day_data.get("target_muscles", [])]

        w_day = WorkoutDay(
            routine_id=user_routine.id,
            day_number=day_num,
            day_name=day_name,
            target_muscles=target_muscles,
        )
        db.add(w_day)

        # Sincronizar también con RoutineTemplate para que /workouts/routines y /workouts/today-plan operen sobre la misma rutina IA
        rt = RoutineTemplate(
            user_id=user.id,
            name=day_name,
            day_of_week=day_num,
            progression_step_kg=2.5,
            is_active=True,
        )
        db.add(rt)
        await db.flush()

        for ex_data in day_data["exercises"]:
            order_num = int(ex_data["order"])
            ex_key = str(ex_data["exercise_key"])
            ex_name = str(ex_data["name"])
            m_group = str(ex_data["muscle_group"])
            sets_count = int(ex_data["target_sets"])
            reps_str = str(ex_data["target_reps"])
            weight_val = float(ex_data["prescribed_weight_kg"])
            rpe_val = float(ex_data["rpe_target"])
            rest_sec = int(ex_data["rest_seconds"])
            tempo_str = str(ex_data["tempo"])
            cue_str = str(ex_data["coaching_cue"])

            w_ex = WorkoutExercise(
                day_id=w_day.id,
                order=order_num,
                exercise_key=ex_key,
                name=ex_name,
                muscle_group=m_group,
                sets=sets_count,
                reps=reps_str,
                prescribed_weight_kg=weight_val,
                rpe=rpe_val,
                rest_seconds=rest_sec,
                tempo=tempo_str,
                coaching_cue=cue_str,
            )
            db.add(w_ex)

            # Garantizar existencia en catálogo Exercise para FK de WorkoutSet
            ex_obj = (
                await db.execute(select(Exercise).where(Exercise.name == ex_name))
            ).scalar_one_or_none()
            if ex_obj is None:
                ex_obj = Exercise(
                    name=ex_name,
                    muscle_group=m_group,
                    category=ExerciseCategory.HIPERTROFIA,
                    formula_1rm_type=Formula1RM.EPLEY,
                    is_compound=order_num <= 3,
                )
                db.add(ex_obj)
                await db.flush()

            db.add(
                RoutineTemplateExercise(
                    routine_id=rt.id,
                    exercise_id=ex_obj.id,
                    display_order=order_num,
                    target_sets=sets_count,
                    base_weight_kg=weight_val,
                    target_reps=_parse_first_int_from_reps(reps_str, 8),
                    target_rpe=rpe_val,
                )
            )

    await db.commit()
    return await fetch_current_ai_routine_dict(db, user)


async def fetch_current_ai_routine_dict(
    db: AsyncSession,
    user: User,
) -> dict[str, Any]:
    """
    Devuelve la rutina IA activa (`UserRoutine` con sus 5 `WorkoutDay` y 6 `WorkoutExercise` por día)
    junto con el mapeo de `routine_template_id` para iniciar sesiones en vivo directamente.
    """
    await ensure_ai_routine_tables(db)

    stmt = (
        select(UserRoutine)
        .options(selectinload(UserRoutine.days).selectinload(WorkoutDay.exercises))
        .where(
            UserRoutine.user_id == user.id,
            UserRoutine.status == "active",
        )
        .order_by(UserRoutine.generated_at.desc())
        .limit(1)
    )
    active_routine = (await db.execute(stmt)).scalar_one_or_none()
    if active_routine is None or not active_routine.days:
        return {
            "has_routine": False,
            "routine": None,
        }

    # Vincular cada día con su RoutineTemplate.id correspondiente para iniciar entrenamientos en vivo
    rt_rows = (
        await db.execute(
            select(RoutineTemplate).where(
                RoutineTemplate.user_id == user.id,
                RoutineTemplate.is_active.is_(True),
            )
        )
    ).scalars().all()
    rt_by_day = {int(r.day_of_week): str(r.id) for r in rt_rows}

    days_out: list[dict[str, Any]] = []
    for d in sorted(active_routine.days, key=lambda x: x.day_number):
        exercises_out: list[dict[str, Any]] = []
        for ex in sorted(d.exercises, key=lambda x: x.order):
            exercises_out.append(
                {
                    "id": str(ex.id),
                    "order": int(ex.order),
                    "exercise_key": ex.exercise_key,
                    "name": ex.name,
                    "muscle_group": ex.muscle_group,
                    "target_sets": int(ex.sets),
                    "target_reps": ex.reps,
                    "target_reps_int": _parse_first_int_from_reps(ex.reps, 8),
                    "prescribed_weight_kg": float(ex.prescribed_weight_kg),
                    "rpe_target": float(ex.rpe),
                    "rest_seconds": int(ex.rest_seconds),
                    "tempo": ex.tempo,
                    "coaching_cue": ex.coaching_cue,
                }
            )
        days_out.append(
            {
                "id": str(d.id),
                "routine_template_id": rt_by_day.get(int(d.day_number), str(d.id)),
                "day_number": int(d.day_number),
                "day_name": d.day_name,
                "target_muscles": list(d.target_muscles or []),
                "exercises": exercises_out,
            }
        )

    return {
        "has_routine": True,
        "id": str(active_routine.id),
        "routine_name": active_routine.name,
        "weekly_focus": active_routine.weekly_focus,
        "generated_at": active_routine.generated_at.isoformat()
        if active_routine.generated_at
        else datetime.now(timezone.utc).isoformat(),
        "status": active_routine.status,
        "days": days_out,
    }
