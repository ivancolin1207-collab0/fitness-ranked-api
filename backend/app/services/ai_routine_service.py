from __future__ import annotations

"""
Motor Cognitivo de Generación de Rutinas y Cargas 100% Dinámico (`ai_routine_service.py`).
CERO MOCKS / CERO CONSTANTES DE OTRO USUARIO:
- Lee `sex` ('male' / 'female'), `weight_kg`, `height_cm`, `body_fat_pct`, `lbm_kg` (real o Boer)
  y `biometric_signature` desde `get_athlete_biometrics(db, user.id)`.
- Lee la telemetría diaria real (`recovery_score`, `sleep_pct`, `strain_score`) desde `get_today_athlete_readiness`.
- Prescribe 5 días × 6 ejercicios exactos por día (3 principales + 3 secundarios) adaptados a `sex` y `% grasa`,
  redondeando a incrementos reales de gimnasio (2.5 kg en barra/máquina, 1.0/2.0 kg en mancuernas)
  e invalidando automáticamente si cambia `biometric_signature`.
"""

import asyncio
import json
import logging
import re
from datetime import datetime, timezone
from typing import Any, Optional

import google.generativeai as genai
from fastapi import HTTPException, status
from sqlalchemy import delete, select, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.elo_engine import ExerciseCategory, Formula1RM
from app.models.entities import (
    Exercise,
    RoutineTemplate,
    RoutineTemplateExercise,
    User,
)
from app.models.routine import UserRoutine, WorkoutDay, WorkoutExercise
from app.services.biometrics_service import (
    get_athlete_biometrics,
    get_today_athlete_readiness,
)
from app.services.gemini_service import _resolve_gemini_api_key

logger = logging.getLogger("apexmetrix_ai_routine")
_AI_ROUTINE_TABLES_READY = False


async def ensure_ai_routine_tables(db: AsyncSession) -> None:
    """Garantiza que `user_routines` (con `biometric_signature`), `workout_days` y `workout_exercises` existan."""
    global _AI_ROUTINE_TABLES_READY
    if _AI_ROUTINE_TABLES_READY:
        return
    await db.execute(
        text(
            """
            CREATE TABLE IF NOT EXISTS user_routines (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                name VARCHAR(180) NOT NULL,
                weekly_focus VARCHAR(240) NOT NULL DEFAULT 'Enfoque biomecánico adaptado a LBM',
                generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                status VARCHAR(30) NOT NULL DEFAULT 'active',
                biometric_signature VARCHAR(80)
            )
            """
        )
    )
    await db.execute(
        text(
            "ALTER TABLE user_routines ADD COLUMN IF NOT EXISTS biometric_signature VARCHAR(80)"
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
                prescribed_weight_kg NUMERIC(6,2) NOT NULL DEFAULT 20.0,
                rpe NUMERIC(3,1) NOT NULL DEFAULT 8.0,
                rest_seconds INTEGER NOT NULL DEFAULT 90,
                tempo VARCHAR(30) NOT NULL DEFAULT '3-0-1-0',
                coaching_cue TEXT NOT NULL DEFAULT 'Controla la fase excéntrica y mantén estabilidad escapular'
            )
            """
        )
    )
    _AI_ROUTINE_TABLES_READY = True


def _parse_first_int_from_reps(reps_str: Any, default_reps: int = 8) -> int:
    if isinstance(reps_str, (int, float)):
        return max(1, int(round(float(reps_str))))
    raw = str(reps_str or "").strip()
    matches = re.findall(r"\d+", raw)
    if not matches:
        return default_reps
    return max(1, int(matches[0]))


def _infer_equipment_from_key_or_name(exercise_key: str, name: str) -> str:
    combined = f"{exercise_key} {name}".lower()
    if any(k in combined for k in ("dumbbell", "mancuerna", "martillo", "lateral_raise")):
        if "cable" not in combined and "polea" not in combined:
            return "dumbbell"
    if any(
        k in combined
        for k in ("cable", "polea", "pulldown", "jalón", "jalon", "pushdown", "gironda", "face_pull")
    ):
        return "cable"
    if any(
        k in combined
        for k in ("machine", "máquina", "maquina", "leg_press", "prensa", "extension", "curl_femoral", "leg_curl", "calf")
    ):
        return "machine"
    return "barbell"


def _round_gym_weight(raw_kg: float, equipment: str, sex: str) -> float:
    """
    Redondea la carga a incrementos reales de gimnasio según implemento y sexo biológico:
    - Mancuernas (`dumbbell`): saltos de 1.0 kg (< 12 kg) o 2.0 kg (>= 12 kg).
    - Barra (`barbell`): saltos de 2.5 kg (mínimo barra olímpica 15 kg mujer / 20 kg hombre).
    - Máquina / Polea (`machine`, `cable`): saltos de 2.5 kg.
    """
    is_female = sex == "female"
    if equipment == "dumbbell":
        floor_w = 2.0 if is_female else 4.0
        clamped = max(floor_w, raw_kg)
        if clamped < 12.0:
            return float(round(clamped))
        return round(round(clamped / 2.0) * 2.0, 1)

    if equipment == "barbell":
        floor_w = 15.0 if is_female else 20.0
        clamped = max(floor_w, raw_kg)
        return round(round(clamped / 2.5) * 2.5, 2)

    floor_w = 5.0 if is_female else 7.5
    clamped = max(floor_w, raw_kg)
    return round(round(clamped / 2.5) * 2.5, 2)


def _resolve_daily_recovery_adjustments(
    recovery_score: Optional[float],
) -> tuple[float, float, float]:
    """
    Ajuste diario según `recovery_score` real del wearable:
    - `< 34%`: reducción del -15% de carga (`0.85`), RPE 6.5–7.0.
    - `34% - 66%` (o `None` sin escaneo hoy): carga base (`1.0`), RPE 7.5–8.0.
    - `>= 67%`: sobrecarga progresiva +4% (`1.04`, rango +2.5% a +5%), RPE 8.5.
    """
    if recovery_score is None:
        return 1.0, 7.5, 8.0
    if recovery_score < 34.0:
        return 0.85, 6.5, 7.0
    if recovery_score <= 66.0:
        return 1.0, 7.5, 8.0
    return 1.04, 8.5, 8.5


def _build_personalized_biomechanical_5x6_plan(
    *,
    full_name: str,
    sex: str,
    weight_kg: float,
    lbm_kg: float,
    body_fat_pct: Optional[float],
    recovery_score: Optional[float],
) -> dict[str, Any]:
    """
    Construye el esquema biomecánico base de 5 días × 6 ejercicios (3 principales + 3 secundarios)
    100% proporcional al `lbm_kg`, diferenciado por `sex` (`female` vs `male`), `% grasa` y `recovery_score`.
    """
    is_female = sex == "female"
    load_mult, comp_rpe, acc_rpe = _resolve_daily_recovery_adjustments(recovery_score)

    # Coeficientes fisiológicos de fuerza relativa por kg de Masa Magra (LBM)
    upper_sex_ratio = 0.62 if is_female else 1.00
    lower_sex_ratio = 0.82 if is_female else 1.00

    # Optimización de densidad metabólica cuando el % grasa corporal busca recomposición activa
    recomp_density = (
        body_fat_pct is not None
        and ((is_female and body_fat_pct >= 30.0) or (not is_female and body_fat_pct >= 24.0))
    )
    comp_rest = 105 if recomp_density else 120
    acc_rest = 60 if recomp_density else 75

    def calc_w(coeff: float, equipment: str, is_lower: bool = False) -> float:
        sex_ratio = lower_sex_ratio if is_lower else upper_sex_ratio
        raw = lbm_kg * coeff * sex_ratio * load_mult
        return _round_gym_weight(raw, equipment, sex)

    if is_female:
        days: list[dict[str, Any]] = [
            {
                "day_number": 1,
                "day_name": "Día 1: Tren Inferior A (Glúteo & Cuádriceps)",
                "target_muscles": ["Glúteo", "Cuádriceps"],
                "exercises": [
                    {
                        "order": 1,
                        "exercise_key": "hip_thrust",
                        "name": "Hip Thrust Pesado con Barra",
                        "muscle_group": "Glúteo",
                        "target_sets": 4,
                        "target_reps": "8-10",
                        "prescribed_weight_kg": calc_w(1.52, "barbell", is_lower=True),
                        "rpe_target": comp_rpe,
                        "rest_seconds": comp_rest,
                        "tempo": "2-0-1-2",
                        "coaching_cue": "Mentón recogido, tibias a 90° e isometría pélvica de 2s arriba",
                    },
                    {
                        "order": 2,
                        "exercise_key": "squat_barbell",
                        "name": "Sentadilla Libre con Barra (Back Squat)",
                        "muscle_group": "Glúteo",
                        "target_sets": 4,
                        "target_reps": "6-8",
                        "prescribed_weight_kg": calc_w(1.34, "barbell", is_lower=True),
                        "rpe_target": comp_rpe,
                        "rest_seconds": comp_rest + 15,
                        "tempo": "3-1-1-0",
                        "coaching_cue": "Bracing 360°, rodillas alineadas y descenso profundo controlado",
                    },
                    {
                        "order": 3,
                        "exercise_key": "bulgarian_split_squat",
                        "name": "Zancadas Búlgaras con Mancuernas (Énfasis Cadera)",
                        "muscle_group": "Glúteo",
                        "target_sets": 3,
                        "target_reps": "8-10",
                        "prescribed_weight_kg": calc_w(0.26, "dumbbell", is_lower=True),
                        "rpe_target": comp_rpe,
                        "rest_seconds": 90,
                        "tempo": "3-1-1-0",
                        "coaching_cue": "Inclina el torso 15° al frente empujando con el talón delantero",
                    },
                    {
                        "order": 4,
                        "exercise_key": "leg_press",
                        "name": "Prensa Inclinada 45° Pies Altos",
                        "muscle_group": "Cuádriceps",
                        "target_sets": 3,
                        "target_reps": "10-12",
                        "prescribed_weight_kg": calc_w(2.25, "machine", is_lower=True),
                        "rpe_target": acc_rpe,
                        "rest_seconds": 90,
                        "tempo": "3-0-1-0",
                        "coaching_cue": "Sacro pegado al respaldo bajando más de 95° de flexión",
                    },
                    {
                        "order": 5,
                        "exercise_key": "leg_extension",
                        "name": "Extensión de Cuádriceps en Máquina",
                        "muscle_group": "Cuádriceps",
                        "target_sets": 3,
                        "target_reps": "12-15",
                        "prescribed_weight_kg": calc_w(0.76, "machine", is_lower=True),
                        "rpe_target": acc_rpe,
                        "rest_seconds": acc_rest,
                        "tempo": "3-0-1-1",
                        "coaching_cue": "Pausa isométrica de 1s arriba exprimiendo el vasto medial",
                    },
                    {
                        "order": 6,
                        "exercise_key": "calf_press_leg_press",
                        "name": "Abducción de Cadera en Máquina",
                        "muscle_group": "Glúteo",
                        "target_sets": 3,
                        "target_reps": "12-15",
                        "prescribed_weight_kg": calc_w(0.92, "machine", is_lower=True),
                        "rpe_target": acc_rpe,
                        "rest_seconds": acc_rest,
                        "tempo": "2-0-1-2",
                        "coaching_cue": "Ligera inclinación anterior para reclutar fibras del glúteo medio",
                    },
                ],
            },
            {
                "day_number": 2,
                "day_name": "Día 2: Tren Superior A (Espalda & Deltoides)",
                "target_muscles": ["Espalda", "Deltoides"],
                "exercises": [
                    {
                        "order": 1,
                        "exercise_key": "lat_pulldown",
                        "name": "Jalón al Pecho Agarre Prono Amplio",
                        "muscle_group": "Espalda",
                        "target_sets": 4,
                        "target_reps": "8-10",
                        "prescribed_weight_kg": calc_w(0.90, "cable"),
                        "rpe_target": comp_rpe,
                        "rest_seconds": 90,
                        "tempo": "3-0-1-1",
                        "coaching_cue": "Inicia deprimiendo escápulas y dirige los codos hacia la cadera",
                    },
                    {
                        "order": 2,
                        "exercise_key": "seated_cable_row",
                        "name": "Remo Gironda en Polea Baja con Pausa",
                        "muscle_group": "Espalda",
                        "target_sets": 4,
                        "target_reps": "8-10",
                        "prescribed_weight_kg": calc_w(0.86, "cable"),
                        "rpe_target": comp_rpe,
                        "rest_seconds": 90,
                        "tempo": "3-0-1-1",
                        "coaching_cue": "Pecho alto y retracción escapular completa durante 1 segundo",
                    },
                    {
                        "order": 3,
                        "exercise_key": "barbell_row",
                        "name": "Remo con Barra Prono 45°",
                        "muscle_group": "Espalda",
                        "target_sets": 3,
                        "target_reps": "8-10",
                        "prescribed_weight_kg": calc_w(0.96, "barbell"),
                        "rpe_target": comp_rpe,
                        "rest_seconds": comp_rest,
                        "tempo": "2-0-1-1",
                        "coaching_cue": "Bisagra de cadera estable llevando la barra al abdomen bajo",
                    },
                    {
                        "order": 4,
                        "exercise_key": "seated_dumbbell_shoulder_press",
                        "name": "Press de Hombros Sentado con Mancuernas",
                        "muscle_group": "Deltoides",
                        "target_sets": 3,
                        "target_reps": "8-10",
                        "prescribed_weight_kg": calc_w(0.32, "dumbbell"),
                        "rpe_target": acc_rpe,
                        "rest_seconds": 90,
                        "tempo": "3-0-1-0",
                        "coaching_cue": "Antebrazos verticales bajando en plano escapular",
                    },
                    {
                        "order": 5,
                        "exercise_key": "lateral_raise",
                        "name": "Elevaciones Laterales con Mancuernas",
                        "muscle_group": "Deltoides",
                        "target_sets": 4,
                        "target_reps": "12-15",
                        "prescribed_weight_kg": calc_w(0.16, "dumbbell"),
                        "rpe_target": acc_rpe,
                        "rest_seconds": acc_rest,
                        "tempo": "3-0-1-1",
                        "coaching_cue": "Eleva a 30° en plano escapular guiando con los codos",
                    },
                    {
                        "order": 6,
                        "exercise_key": "rear_delt_fly",
                        "name": "Face Pull en Polea Alta (Deltoides Posterior)",
                        "muscle_group": "Deltoides",
                        "target_sets": 3,
                        "target_reps": "12-15",
                        "prescribed_weight_kg": calc_w(0.42, "cable"),
                        "rpe_target": acc_rpe,
                        "rest_seconds": acc_rest,
                        "tempo": "2-0-1-1",
                        "coaching_cue": "Tracciona hacia la frente abriendo cuerda en rotación externa",
                    },
                ],
            },
            {
                "day_number": 3,
                "day_name": "Día 3: Tren Inferior B (Isquiosurales & Cadena Posterior)",
                "target_muscles": ["Isquiosurales", "Glúteo"],
                "exercises": [
                    {
                        "order": 1,
                        "exercise_key": "deadlift_barbell",
                        "name": "Peso Muerto Rumano con Barra (RDL)",
                        "muscle_group": "Isquiosurales",
                        "target_sets": 4,
                        "target_reps": "6-8",
                        "prescribed_weight_kg": calc_w(1.28, "barbell", is_lower=True),
                        "rpe_target": comp_rpe,
                        "rest_seconds": comp_rest + 15,
                        "tempo": "3-1-1-0",
                        "coaching_cue": "Barra rozando los muslos y cadera atrás sintiendo máximo estiramiento",
                    },
                    {
                        "order": 2,
                        "exercise_key": "seated_leg_curl",
                        "name": "Curl Femoral Sentado con Pausa",
                        "muscle_group": "Isquiosurales",
                        "target_sets": 4,
                        "target_reps": "10-12",
                        "prescribed_weight_kg": calc_w(0.74, "machine", is_lower=True),
                        "rpe_target": acc_rpe,
                        "rest_seconds": 90,
                        "tempo": "3-0-1-1",
                        "coaching_cue": "Dorsiflexión activa de tobillo y fase excéntrica de 3 segundos",
                    },
                    {
                        "order": 3,
                        "exercise_key": "hyperextension_weighted",
                        "name": "Extensión de Cadera 45° Lastrada",
                        "muscle_group": "Isquiosurales",
                        "target_sets": 3,
                        "target_reps": "12-15",
                        "prescribed_weight_kg": calc_w(0.26, "dumbbell", is_lower=True),
                        "rpe_target": acc_rpe,
                        "rest_seconds": acc_rest,
                        "tempo": "2-0-1-1",
                        "coaching_cue": " Bisagra pura desde la cadera contrayendo glúteo e isquios arriba",
                    },
                    {
                        "order": 4,
                        "exercise_key": "lunge_dumbbell",
                        "name": "Zancadas Caminando Largas con Mancuernas",
                        "muscle_group": "Glúteo",
                        "target_sets": 3,
                        "target_reps": "10-12",
                        "prescribed_weight_kg": calc_w(0.25, "dumbbell", is_lower=True),
                        "rpe_target": comp_rpe,
                        "rest_seconds": 90,
                        "tempo": "3-0-1-0",
                        "coaching_cue": "Paso amplio manteniendo rodilla estable sobre el segundo dedo del pie",
                    },
                    {
                        "order": 5,
                        "exercise_key": "standing_calf_raise",
                        "name": "Elevación de Talones de Pie en Máquina",
                        "muscle_group": "Gemelos",
                        "target_sets": 3,
                        "target_reps": "10-12",
                        "prescribed_weight_kg": calc_w(1.05, "machine", is_lower=True),
                        "rpe_target": acc_rpe,
                        "rest_seconds": 60,
                        "tempo": "2-2-1-1",
                        "coaching_cue": "Pausa de 2s abajo para anular el reflejo elástico del Aquiles",
                    },
                    {
                        "order": 6,
                        "exercise_key": "seated_calf_raise",
                        "name": "Elevación de Talones Sentado (Sóleo)",
                        "muscle_group": "Gemelos",
                        "target_sets": 3,
                        "target_reps": "12-15",
                        "prescribed_weight_kg": calc_w(0.68, "machine", is_lower=True),
                        "rpe_target": acc_rpe,
                        "rest_seconds": 60,
                        "tempo": "3-1-1-1",
                        "coaching_cue": "Recorrido completo manteniendo presión uniforme sobre el metatarso",
                    },
                ],
            },
            {
                "day_number": 4,
                "day_name": "Día 4: Tren Superior B (Empuje Torácico & Brazos)",
                "target_muscles": ["Pectoral", "Brazos"],
                "exercises": [
                    {
                        "order": 1,
                        "exercise_key": "incline_dumbbell_press",
                        "name": "Press Inclinado con Mancuernas (30°)",
                        "muscle_group": "Pectoral",
                        "target_sets": 4,
                        "target_reps": "8-10",
                        "prescribed_weight_kg": calc_w(0.38, "dumbbell"),
                        "rpe_target": comp_rpe,
                        "rest_seconds": 90,
                        "tempo": "3-1-1-0",
                        "coaching_cue": "Escápulas retraídas y codos a 45° cuidando estabilidad glenohumeral",
                    },
                    {
                        "order": 2,
                        "exercise_key": "bench_press_barbell",
                        "name": "Press de Banca Plano con Barra",
                        "muscle_group": "Pectoral",
                        "target_sets": 3,
                        "target_reps": "6-8",
                        "prescribed_weight_kg": calc_w(0.96, "barbell"),
                        "rpe_target": comp_rpe,
                        "rest_seconds": comp_rest,
                        "tempo": "3-0-1-0",
                        "coaching_cue": "Arco natural, pies firmes y descenso controlado al esternón",
                    },
                    {
                        "order": 3,
                        "exercise_key": "chest_dip_weighted",
                        "name": "Cruce en Polea Media (Aducción Pectoral)",
                        "muscle_group": "Pectoral",
                        "target_sets": 3,
                        "target_reps": "12-15",
                        "prescribed_weight_kg": calc_w(0.34, "cable"),
                        "rpe_target": acc_rpe,
                        "rest_seconds": acc_rest,
                        "tempo": "3-0-1-1",
                        "coaching_cue": "Mantén ligera flexión de codos y une húmeros frente al esternón",
                    },
                    {
                        "order": 4,
                        "exercise_key": "tricep_rope_pushdown",
                        "name": "Extensión de Tríceps en Polea con Cuerda",
                        "muscle_group": "Tríceps",
                        "target_sets": 3,
                        "target_reps": "10-12",
                        "prescribed_weight_kg": calc_w(0.42, "cable"),
                        "rpe_target": acc_rpe,
                        "rest_seconds": acc_rest,
                        "tempo": "2-0-1-1",
                        "coaching_cue": "Codos fijos al torso abriendo la cuerda al finalizar la extensión",
                    },
                    {
                        "order": 5,
                        "exercise_key": "incline_dumbbell_curl",
                        "name": "Curl de Bíceps Alterno con Mancuernas",
                        "muscle_group": "Bíceps",
                        "target_sets": 3,
                        "target_reps": "10-12",
                        "prescribed_weight_kg": calc_w(0.22, "dumbbell"),
                        "rpe_target": acc_rpe,
                        "rest_seconds": acc_rest,
                        "tempo": "3-0-1-1",
                        "coaching_cue": "Supina la muñeca al subir evitando balancear la cadera",
                    },
                    {
                        "order": 6,
                        "exercise_key": "overhead_tricep_extension",
                        "name": "Extensión de Tríceps Trasnuca en Polea",
                        "muscle_group": "Tríceps",
                        "target_sets": 3,
                        "target_reps": "12-15",
                        "prescribed_weight_kg": calc_w(0.36, "cable"),
                        "rpe_target": acc_rpe,
                        "rest_seconds": acc_rest,
                        "tempo": "3-1-1-0",
                        "coaching_cue": "Abdomen compacto y estiramiento completo de la cabeza larga",
                    },
                ],
            },
            {
                "day_number": 5,
                "day_name": "Día 5: Simetría Glúteo Medio, Femoral & Deltoides",
                "target_muscles": ["Glúteo", "Deltoides"],
                "exercises": [
                    {
                        "order": 1,
                        "exercise_key": "hip_thrust",
                        "name": "Puente de Glúteo con Barra (Pausa 2s)",
                        "muscle_group": "Glúteo",
                        "target_sets": 4,
                        "target_reps": "10-12",
                        "prescribed_weight_kg": calc_w(1.42, "barbell", is_lower=True),
                        "rpe_target": comp_rpe,
                        "rest_seconds": 90,
                        "tempo": "2-0-1-2",
                        "coaching_cue": "Recorrido corto de máxima tensión en extensión de cadera",
                    },
                    {
                        "order": 2,
                        "exercise_key": "deadlift_barbell",
                        "name": "Peso Muerto Rumano con Mancuernas",
                        "muscle_group": "Glúteo",
                        "target_sets": 3,
                        "target_reps": "10-12",
                        "prescribed_weight_kg": calc_w(0.36, "dumbbell", is_lower=True),
                        "rpe_target": comp_rpe,
                        "rest_seconds": 90,
                        "tempo": "3-1-1-0",
                        "coaching_cue": "Mancuernas pegadas a las tibias manteniendo columna neutra",
                    },
                    {
                        "order": 3,
                        "exercise_key": "calf_press_leg_press",
                        "name": "Patada de Glúteo en Polea Baja",
                        "muscle_group": "Glúteo",
                        "target_sets": 3,
                        "target_reps": "12-15",
                        "prescribed_weight_kg": calc_w(0.32, "cable", is_lower=True),
                        "rpe_target": acc_rpe,
                        "rest_seconds": acc_rest,
                        "tempo": "2-0-1-2",
                        "coaching_cue": "Extiende cadera 20° con ligera rotación externa sin arquear zona lumbar",
                    },
                    {
                        "order": 4,
                        "exercise_key": "cable_lateral_raise",
                        "name": "Elevación Lateral Unilateral en Polea Baja",
                        "muscle_group": "Deltoides",
                        "target_sets": 4,
                        "target_reps": "12-15",
                        "prescribed_weight_kg": calc_w(0.18, "cable"),
                        "rpe_target": acc_rpe,
                        "rest_seconds": acc_rest,
                        "tempo": "3-0-1-1",
                        "coaching_cue": "Tensión continua desde los primeros grados de abducción",
                    },
                    {
                        "order": 5,
                        "exercise_key": "overhead_press",
                        "name": "Press Militar con Barra (OHP)",
                        "muscle_group": "Deltoides",
                        "target_sets": 3,
                        "target_reps": "8-10",
                        "prescribed_weight_kg": calc_w(0.62, "barbell"),
                        "rpe_target": comp_rpe,
                        "rest_seconds": 90,
                        "tempo": "2-0-1-1",
                        "coaching_cue": "Glúteo y core firmes empujando en línea vertical sobre la coronilla",
                    },
                    {
                        "order": 6,
                        "exercise_key": "rear_delt_fly",
                        "name": "Pájaros Posteriores en Máquina / Polea",
                        "muscle_group": "Deltoides",
                        "target_sets": 3,
                        "target_reps": "12-15",
                        "prescribed_weight_kg": calc_w(0.38, "machine"),
                        "rpe_target": acc_rpe,
                        "rest_seconds": acc_rest,
                        "tempo": "3-0-1-1",
                        "coaching_cue": "Aísla el deltoides posterior sin juntar escápulas en exceso",
                    },
                ],
            },
        ]
    else:
        days = [
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
                        "prescribed_weight_kg": calc_w(1.02, "barbell"),
                        "rpe_target": comp_rpe,
                        "rest_seconds": comp_rest,
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
                        "prescribed_weight_kg": calc_w(0.40, "dumbbell"),
                        "rpe_target": comp_rpe,
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
                        "prescribed_weight_kg": calc_w(0.36, "cable"),
                        "rpe_target": comp_rpe,
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
                        "prescribed_weight_kg": calc_w(0.46, "barbell"),
                        "rpe_target": acc_rpe,
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
                        "prescribed_weight_kg": calc_w(0.42, "cable"),
                        "rpe_target": acc_rpe,
                        "rest_seconds": acc_rest,
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
                        "prescribed_weight_kg": calc_w(0.36, "cable"),
                        "rpe_target": acc_rpe,
                        "rest_seconds": acc_rest,
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
                        "prescribed_weight_kg": calc_w(1.06, "barbell"),
                        "rpe_target": comp_rpe,
                        "rest_seconds": comp_rest,
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
                        "prescribed_weight_kg": calc_w(0.92, "cable"),
                        "rpe_target": comp_rpe,
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
                        "prescribed_weight_kg": calc_w(0.86, "cable"),
                        "rpe_target": comp_rpe,
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
                        "prescribed_weight_kg": calc_w(0.50, "barbell"),
                        "rpe_target": acc_rpe,
                        "rest_seconds": acc_rest,
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
                        "prescribed_weight_kg": calc_w(0.22, "dumbbell"),
                        "rpe_target": acc_rpe,
                        "rest_seconds": acc_rest,
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
                        "prescribed_weight_kg": calc_w(0.25, "dumbbell"),
                        "rpe_target": acc_rpe,
                        "rest_seconds": acc_rest,
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
                        "prescribed_weight_kg": calc_w(1.36, "barbell", is_lower=True),
                        "rpe_target": comp_rpe,
                        "rest_seconds": comp_rest + 30,
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
                        "prescribed_weight_kg": calc_w(2.30, "machine", is_lower=True),
                        "rpe_target": comp_rpe,
                        "rest_seconds": comp_rest,
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
                        "prescribed_weight_kg": calc_w(0.30, "dumbbell", is_lower=True),
                        "rpe_target": comp_rpe,
                        "rest_seconds": 90,
                        "tempo": "3-1-1-0",
                        "coaching_cue": "Empuja con toda la planta del pie delantero manteniendo pelvis nivelada",
                    },
                    {
                        "order": 4,
                        "exercise_key": "leg_extension",
                        "name": "Extensión de Cuádriceps en Máquina (Isometría)",
                        "muscle_group": "Gemelos",
                        "target_sets": 3,
                        "target_reps": "12-15",
                        "prescribed_weight_kg": calc_w(0.80, "machine", is_lower=True),
                        "rpe_target": acc_rpe,
                        "rest_seconds": acc_rest,
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
                        "prescribed_weight_kg": calc_w(1.12, "machine", is_lower=True),
                        "rpe_target": acc_rpe,
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
                        "prescribed_weight_kg": calc_w(0.72, "machine", is_lower=True),
                        "rpe_target": acc_rpe,
                        "rest_seconds": 60,
                        "tempo": "3-1-1-1",
                        "coaching_cue": "Rango completo sobre el metatarso manteniendo tensión constante",
                    },
                ],
            },
            {
                "day_number": 4,
                "day_name": "Día 4: Hombros & Trapecio",
                "target_muscles": ["Deltoides", "Trapecio"],
                "exercises": [
                    {
                        "order": 1,
                        "exercise_key": "overhead_press",
                        "name": "Press Militar Overhead con Barra (OHP)",
                        "muscle_group": "Deltoides",
                        "target_sets": 4,
                        "target_reps": "6-8",
                        "prescribed_weight_kg": calc_w(0.66, "barbell"),
                        "rpe_target": comp_rpe,
                        "rest_seconds": comp_rest,
                        "tempo": "2-0-1-1",
                        "coaching_cue": "Glúteos y abdomen en bracing total, antebrazos verticales bajo la barra",
                    },
                    {
                        "order": 2,
                        "exercise_key": "seated_dumbbell_shoulder_press",
                        "name": "Press de Hombros Sentado con Mancuernas",
                        "muscle_group": "Deltoides",
                        "target_sets": 3,
                        "target_reps": "8-10",
                        "prescribed_weight_kg": calc_w(0.34, "dumbbell"),
                        "rpe_target": comp_rpe,
                        "rest_seconds": 90,
                        "tempo": "3-0-1-0",
                        "coaching_cue": "Desciende hasta que las mancuernas rocen la línea de las orejas",
                    },
                    {
                        "order": 3,
                        "exercise_key": "lateral_raise",
                        "name": "Elevaciones Laterales en Plano Escapular",
                        "muscle_group": "Deltoides",
                        "target_sets": 4,
                        "target_reps": "12-15",
                        "prescribed_weight_kg": calc_w(0.18, "dumbbell"),
                        "rpe_target": acc_rpe,
                        "rest_seconds": acc_rest,
                        "tempo": "3-0-1-1",
                        "coaching_cue": "Eleva a 30° en plano escapular guiando con los codos sin encoger trapecios",
                    },
                    {
                        "order": 4,
                        "exercise_key": "rear_delt_fly",
                        "name": "Face Pull / Pájaros en Polea (Deltoides Posterior)",
                        "muscle_group": "Trapecio",
                        "target_sets": 3,
                        "target_reps": "12-15",
                        "prescribed_weight_kg": calc_w(0.38, "cable"),
                        "rpe_target": acc_rpe,
                        "rest_seconds": acc_rest,
                        "tempo": "2-0-1-1",
                        "coaching_cue": "Tracciona hacia la frente con rotación externa de hombro al final",
                    },
                    {
                        "order": 5,
                        "exercise_key": "barbell_shrug",
                        "name": "Encogimientos con Barra (Trapecio Superior)",
                        "muscle_group": "Trapecio",
                        "target_sets": 3,
                        "target_reps": "10-12",
                        "prescribed_weight_kg": calc_w(1.18, "barbell"),
                        "rpe_target": acc_rpe,
                        "rest_seconds": acc_rest,
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
                        "prescribed_weight_kg": calc_w(0.16, "cable"),
                        "rpe_target": acc_rpe,
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
                        "prescribed_weight_kg": calc_w(1.30, "barbell", is_lower=True),
                        "rpe_target": comp_rpe,
                        "rest_seconds": comp_rest + 30,
                        "tempo": "3-1-1-0",
                        "coaching_cue": "Barra pegada a los muslos, empuja la cadera atrás sintiendo tensión isquiosural",
                    },
                    {
                        "order": 2,
                        "exercise_key": "seated_leg_curl",
                        "name": "Curl Femoral Sentado / Tumbado",
                        "muscle_group": "Isquiosurales",
                        "target_sets": 4,
                        "target_reps": "10-12",
                        "prescribed_weight_kg": calc_w(0.75, "machine", is_lower=True),
                        "rpe_target": acc_rpe,
                        "rest_seconds": 90,
                        "tempo": "3-0-1-1",
                        "coaching_cue": "Dorsiflexión de tobillo activa y fase excéntrica de 3 segundos sin despegar cadera",
                    },
                    {
                        "order": 3,
                        "exercise_key": "hyperextension_weighted",
                        "name": "Extensión de Cadera 45° Lastrada",
                        "muscle_group": "Isquiosurales",
                        "target_sets": 3,
                        "target_reps": "12-15",
                        "prescribed_weight_kg": calc_w(0.28, "dumbbell", is_lower=True),
                        "rpe_target": acc_rpe,
                        "rest_seconds": acc_rest,
                        "tempo": "2-0-1-1",
                        "coaching_cue": "Redondea ligeramente la zona dorsal alta para aislar glúteo e isquios",
                    },
                    {
                        "order": 4,
                        "exercise_key": "hip_thrust",
                        "name": "Hip Thrust Pesado con Barra",
                        "muscle_group": "Glúteo",
                        "target_sets": 4,
                        "target_reps": "8-10",
                        "prescribed_weight_kg": calc_w(1.50, "barbell", is_lower=True),
                        "rpe_target": comp_rpe,
                        "rest_seconds": comp_rest,
                        "tempo": "2-0-1-2",
                        "coaching_cue": "Mentón recogido, tibias a 90° y retroversión pélvica de 2s en el bloqueo",
                    },
                    {
                        "order": 5,
                        "exercise_key": "lunge_dumbbell",
                        "name": "Zancadas Caminando Largas (Énfasis Glúteo)",
                        "muscle_group": "Glúteo",
                        "target_sets": 3,
                        "target_reps": "10-12",
                        "prescribed_weight_kg": calc_w(0.30, "dumbbell", is_lower=True),
                        "rpe_target": comp_rpe,
                        "rest_seconds": 90,
                        "tempo": "3-0-1-0",
                        "coaching_cue": "Zancada larga e inclinación de 15° en el torso para maximizar torque de cadera",
                    },
                    {
                        "order": 6,
                        "exercise_key": "calf_press_leg_press",
                        "name": "Prensa de Gemelos / Abducción de Cadera",
                        "muscle_group": "Glúteo",
                        "target_sets": 3,
                        "target_reps": "12-15",
                        "prescribed_weight_kg": calc_w(0.92, "machine", is_lower=True),
                        "rpe_target": acc_rpe,
                        "rest_seconds": 60,
                        "tempo": "3-1-1-1",
                        "coaching_cue": "Control total en ambos extremos del rango articular sin impulso",
                    },
                ],
            },
        ]

    fat_txt = f" • Grasa {body_fat_pct:.1f}%" if body_fat_pct is not None else " • LBM Boer"
    rec_txt = (
        f" • Rec {recovery_score:.0f}%"
        if recovery_score is not None
        else " • Carga Base (Sin escaneo hoy)"
    )
    sex_label = "Femenino" if is_female else "Masculino"
    return {
        "routine_name": f"Periodización Adaptativa IA • {full_name}",
        "weekly_focus": (
            f"Perfil {sex_label} • {lbm_kg:.2f} kg LBM "
            f"(Peso {weight_kg:.1f} kg{fat_txt}{rec_txt})"
        ),
        "days": days,
    }


def _normalize_and_validate_ai_plan(
    raw_plan: dict[str, Any],
    base_plan: dict[str, Any],
    sex: str,
) -> dict[str, Any]:
    """
    Valida que el JSON de Gemini cumpla estrictamente con:
    - 5 días de entrenamiento, estrictamente 6 ejercicios por día (3 principales + 3 secundarios).
    - Redondeo exacto por implemento (2.5 kg barra/máquina, 1.0/2.0 kg mancuernas) dentro del rango LBM real del atleta.
    """
    raw_days = raw_plan.get("days")
    if not isinstance(raw_days, list) or len(raw_days) == 0:
        return base_plan

    base_days = base_plan["days"]
    normalized_days: list[dict[str, Any]] = []

    for day_idx in range(5):
        ref_day = base_days[day_idx]
        src_day = (
            raw_days[day_idx]
            if day_idx < len(raw_days) and isinstance(raw_days[day_idx], dict)
            else ref_day
        )

        raw_exercises = src_day.get("exercises")
        if not isinstance(raw_exercises, list):
            raw_exercises = []

        normalized_exercises: list[dict[str, Any]] = []
        for ex_idx in range(6):
            ref_ex = ref_day["exercises"][ex_idx]
            src_ex = (
                raw_exercises[ex_idx]
                if ex_idx < len(raw_exercises) and isinstance(raw_exercises[ex_idx], dict)
                else ref_ex
            )
            ex_key = str(src_ex.get("exercise_key") or ref_ex["exercise_key"]).strip()
            ex_name = str(src_ex.get("name") or ref_ex["name"]).strip()
            equip = _infer_equipment_from_key_or_name(ex_key, ex_name)

            raw_w = src_ex.get("prescribed_weight_kg")
            ref_w = float(ref_ex["prescribed_weight_kg"])
            try:
                parsed_w = float(raw_w) if raw_w is not None else ref_w
                if parsed_w <= 1.0:
                    parsed_w = ref_w
                else:
                    parsed_w = max(ref_w * 0.80, min(ref_w * 1.15, parsed_w))
            except Exception:
                parsed_w = ref_w

            try:
                parsed_sets = int(src_ex.get("target_sets") or ref_ex["target_sets"])
                parsed_sets = max(2, min(6, parsed_sets))
            except Exception:
                parsed_sets = int(ref_ex["target_sets"])

            try:
                parsed_rpe = float(src_ex.get("rpe_target") or ref_ex["rpe_target"])
                parsed_rpe = max(6.0, min(9.5, round(parsed_rpe, 1)))
            except Exception:
                parsed_rpe = float(ref_ex["rpe_target"])

            try:
                parsed_rest = int(src_ex.get("rest_seconds") or ref_ex["rest_seconds"])
                parsed_rest = max(45, min(240, parsed_rest))
            except Exception:
                parsed_rest = int(ref_ex["rest_seconds"])

            normalized_exercises.append(
                {
                    "order": ex_idx + 1,
                    "exercise_key": ex_key,
                    "name": ex_name,
                    "muscle_group": str(
                        src_ex.get("muscle_group") or ref_ex["muscle_group"]
                    ).strip(),
                    "target_sets": parsed_sets,
                    "target_reps": str(
                        src_ex.get("target_reps") or ref_ex["target_reps"]
                    ).strip(),
                    "prescribed_weight_kg": _round_gym_weight(parsed_w, equip, sex),
                    "rpe_target": parsed_rpe,
                    "rest_seconds": parsed_rest,
                    "tempo": str(src_ex.get("tempo") or ref_ex["tempo"]).strip(),
                    "coaching_cue": str(
                        src_ex.get("coaching_cue") or ref_ex["coaching_cue"]
                    ).strip(),
                }
            )

        raw_targets = src_day.get("target_muscles")
        if not isinstance(raw_targets, list) or not raw_targets:
            raw_targets = ref_day["target_muscles"]

        normalized_days.append(
            {
                "day_number": day_idx + 1,
                "day_name": str(src_day.get("day_name") or ref_day["day_name"]).strip(),
                "target_muscles": [str(m) for m in raw_targets],
                "exercises": normalized_exercises,
            }
        )

    return {
        "routine_name": str(
            raw_plan.get("routine_name") or base_plan["routine_name"]
        ).strip(),
        "weekly_focus": str(
            raw_plan.get("weekly_focus") or base_plan["weekly_focus"]
        ).strip(),
        "days": normalized_days,
    }


async def generate_and_persist_ai_routine(
    db: AsyncSession,
    user: User,
) -> dict[str, Any]:
    """
    Lee en tiempo real los datos biométricos (`get_athlete_biometrics`) y la telemetría de hoy
    (`get_today_athlete_readiness`) del `user.id` autenticado, invoca a Gemini 2.5 Flash
    sin valores quemados de ningún otro usuario, y guarda en PostgreSQL con `biometric_signature`.
    """
    await ensure_ai_routine_tables(db)

    bio = await get_athlete_biometrics(db, user.id)
    if not bio["has_complete_biometrics"] or bio["weight_kg"] is None or bio["lbm_kg"] is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Configura primero tu sexo biológico, peso actual (kg) y estatura (cm) "
                "en tu perfil (o escanea Fitdays) para calcular tus cargas personalizadas reales."
            ),
        )

    sex: str = bio["sex"]
    weight_kg: float = float(bio["weight_kg"])
    height_cm: Optional[float] = bio["height_cm"]
    body_fat_pct: Optional[float] = bio["body_fat_pct"]
    lbm_kg: float = float(bio["lbm_kg"])
    biometric_signature: str = str(bio["biometric_signature"])

    readiness = await get_today_athlete_readiness(db, user.id)
    recovery_score: Optional[float] = readiness["recovery_score"]
    sleep_pct: Optional[float] = readiness["sleep_pct"]
    strain_score: Optional[float] = readiness["strain_score"]

    full_name = (user.full_name or user.username or "Atleta").strip()

    base_plan = _build_personalized_biomechanical_5x6_plan(
        full_name=full_name,
        sex=sex,
        weight_kg=weight_kg,
        lbm_kg=lbm_kg,
        body_fat_pct=body_fat_pct,
        recovery_score=recovery_score,
    )

    ref_ex_1 = base_plan["days"][0]["exercises"][0]
    ref_ex_2 = base_plan["days"][1]["exercises"][0]
    ref_ex_3 = base_plan["days"][2]["exercises"][0]

    height_str = f"{height_cm:.0f} cm" if height_cm is not None else "No registrada"
    fat_str = (
        f"{body_fat_pct:.1f}% (medida)"
        if body_fat_pct is not None
        else f"Estimación LBM por Fórmula de Boer ({sex})"
    )
    readiness_str = (
        f"Recuperación: {recovery_score:.0f}% | Sueño: {float(sleep_pct or 0.0):.0f}% | Strain: {float(strain_score or 0.0):.1f}"
        if recovery_score is not None
        else "Sin wearable sincronizado hoy (usar carga base 1.0x @ RPE 7.5-8.0)"
    )
    load_mult, comp_rpe, acc_rpe = _resolve_daily_recovery_adjustments(recovery_score)

    prompt = f"""
Diseña una periodización semanal de fuerza e hipertrofia 100% PERSONALIZADA para el usuario autenticado:
- Atleta: {full_name} (user_id: {user.id})
- Sexo biológico (`sex`): {sex}
- Peso corporal real (`weight_kg`): {weight_kg:.1f} kg
- Estatura (`height_cm`): {height_str}
- Masa Magra Libre de Grasa (`lbm_kg`): {lbm_kg:.2f} kg
- Grasa corporal (`body_fat_pct`): {fat_str}
- Telemetría diaria real: {readiness_str}
- Factor diario de carga aplicado: {load_mult:.2f}x | RPE objetivo compuestos: {comp_rpe:.1f} | RPE accesorios: {acc_rpe:.1f}

REGLAS OBLIGATORIAS:
1. Estructura estricta: EXACTAMENTE 5 días de entrenamiento (`day_number` 1 a 5) y ESTRICTAMENTE 6 ejercicios por día (3 del grupo muscular principal + 3 del secundario).
2. Selección biomecánica y distribución de volumen adaptada a `sex = {sex}` y composición corporal (`{fat_str}`).
3. Cálculo matemático real de `prescribed_weight_kg` directamente proporcional a `{lbm_kg:.2f} kg LBM` y coeficientes de fuerza de tren superior e inferior para `{sex}`:
   - Referencias exactas para ESTE usuario hoy:
     * {ref_ex_1['name']}: {ref_ex_1['prescribed_weight_kg']} kg
     * {ref_ex_2['name']}: {ref_ex_2['prescribed_weight_kg']} kg
     * {ref_ex_3['name']}: {ref_ex_3['prescribed_weight_kg']} kg
   - Redondea barras/máquinas a múltiplos de 2.5 kg y mancuernas a múltiplos de 1.0 o 2.0 kg.
   - PROHIBIDO usar rutinas o pesos genéricos de otro usuario.
4. Responde ÚNICAMENTE con un objeto JSON válido con las claves:
   `routine_name`, `weekly_focus` y `days` (lista de 5 días, cada uno con `day_number`, `day_name`, `target_muscles` y `exercises` con `order`, `exercise_key`, `name`, `muscle_group`, `target_sets`, `target_reps`, `prescribed_weight_kg`, `rpe_target`, `rest_seconds`, `tempo`, `coaching_cue`).
""".strip()

    final_plan = base_plan
    api_key = _resolve_gemini_api_key()
    if api_key:
        try:
            genai.configure(api_key=api_key)
            model = genai.GenerativeModel(
                "gemini-2.5-flash",
                generation_config={
                    "temperature": 0.25,
                    "response_mime_type": "application/json",
                },
            )
            response = await asyncio.wait_for(
                asyncio.to_thread(model.generate_content, prompt),
                timeout=18.0,
            )
            raw_text = (getattr(response, "text", None) or "").strip()
            json_match = re.search(r"\{.*\}", raw_text, re.DOTALL)
            if json_match:
                parsed_json = json.loads(json_match.group(0))
                if isinstance(parsed_json, dict):
                    final_plan = _normalize_and_validate_ai_plan(
                        raw_plan=parsed_json,
                        base_plan=base_plan,
                        sex=sex,
                    )
        except Exception as exc:
            logger.warning(
                "Usando cálculo matemático directo por LBM tras timeout/error de Gemini: %s",
                exc,
            )

    # Reemplazar atómicamente cualquier rutina previa de este usuario en PostgreSQL
    await db.execute(delete(UserRoutine).where(UserRoutine.user_id == user.id))
    await db.execute(delete(RoutineTemplate).where(RoutineTemplate.user_id == user.id))
    await db.flush()

    user_routine = UserRoutine(
        user_id=user.id,
        name=final_plan["routine_name"],
        weekly_focus=final_plan["weekly_focus"],
        generated_at=datetime.now(timezone.utc),
        status="active",
        biometric_signature=biometric_signature,
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
    persisted = await fetch_current_ai_routine_dict(
        db, user, _skip_signature_regeneration=True
    )
    return {
        "status": "success",
        "routine": persisted,
        **persisted,
    }


async def fetch_current_ai_routine_dict(
    db: AsyncSession,
    user: User,
    *,
    _skip_signature_regeneration: bool = False,
) -> dict[str, Any]:
    """
    Devuelve la rutina IA activa de `user.id` en PostgreSQL.
    - Si el usuario aún no tiene peso/estatura/LBM configurados: retorna `requires_biometrics = True`.
    - Si existe una rutina cuya `biometric_signature` difiere de la huella actual del atleta
      (porque actualizó su peso, escaneó Fitdays o cambió de sexo en su perfil), regenera
      automáticamente la rutina y cargas en PostgreSQL antes de responder.
    """
    await ensure_ai_routine_tables(db)
    bio = await get_athlete_biometrics(db, user.id)

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

    if not bio["has_complete_biometrics"]:
        return {
            "has_routine": False,
            "requires_biometrics": True,
            "sex": bio["sex"],
            "weight_kg": bio["weight_kg"],
            "lbm_kg": bio["lbm_kg"],
            "body_fat_pct": bio["body_fat_pct"],
            "biometric_signature": None,
            "routine": None,
        }

    current_sig = bio["biometric_signature"]
    if (
        not _skip_signature_regeneration
        and active_routine is not None
        and current_sig
        and active_routine.biometric_signature != current_sig
    ):
        logger.info(
            "Cambio detectado en biometric_signature (%s -> %s) para user=%s; regenerando rutina.",
            active_routine.biometric_signature,
            current_sig,
            user.id,
        )
        regenerated = await generate_and_persist_ai_routine(db, user)
        return regenerated.get("routine") or regenerated

    if active_routine is None or not active_routine.days:
        return {
            "has_routine": False,
            "requires_biometrics": False,
            "sex": bio["sex"],
            "weight_kg": bio["weight_kg"],
            "lbm_kg": bio["lbm_kg"],
            "body_fat_pct": bio["body_fat_pct"],
            "biometric_signature": current_sig,
            "routine": None,
        }

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
        "requires_biometrics": False,
        "id": str(active_routine.id),
        "routine_name": active_routine.name,
        "weekly_focus": active_routine.weekly_focus,
        "biometric_signature": active_routine.biometric_signature or current_sig,
        "sex": bio["sex"],
        "weight_kg": bio["weight_kg"],
        "lbm_kg": bio["lbm_kg"],
        "body_fat_pct": bio["body_fat_pct"],
        "generated_at": active_routine.generated_at.isoformat()
        if active_routine.generated_at
        else datetime.now(timezone.utc).isoformat(),
        "status": active_routine.status,
        "days": days_out,
    }
