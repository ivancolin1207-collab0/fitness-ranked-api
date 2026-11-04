from __future__ import annotations

"""
Motor Competitivo de Metrología Deportiva, Normalización Alométrica (DOTS / LBM^0.67)
y Algoritmo ELO Dinámico (Sesiones Individuales, Duelos 1v1 y Ranking Global).
"""

import math
from dataclasses import dataclass
from enum import Enum
from typing import Sequence


class UnitSystem(str, Enum):
    KG = "KG"
    LB = "LB"


class BiologicalSex(str, Enum):
    MALE = "MALE"
    FEMALE = "FEMALE"


class WearableSource(str, Enum):
    HEALTH_CONNECT = "HEALTH_CONNECT"
    GOOGLE_FIT = "GOOGLE_FIT"
    WHOOP = "WHOOP"
    HUAWEI_GT = "HUAWEI_GT"
    GARMIN = "GARMIN"


class ExerciseCategory(str, Enum):
    FUERZA = "fuerza"
    HIPERTROFIA = "hipertrofia"
    CARDIO = "cardio"


class Formula1RM(str, Enum):
    EPLEY = "EPLEY"
    BRZYCKI = "BRZYCKI"
    LOMBARDI = "LOMBARDI"
    MAYHEW = "MAYHEW"


class WorkoutStatus(str, Enum):
    PLANNED = "PLANNED"
    IN_PROGRESS = "IN_PROGRESS"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"


class CompetitionType(str, Enum):
    ONE_VS_ONE = "1v1"
    TEAM_VS_TEAM = "team_vs_team"
    GLOBAL_LEADERBOARD = "global_leaderboard"


class MetricTarget(str, Enum):
    DOTS_RELATIVE_VOLUME = "DOTS_RELATIVE_VOLUME"
    LBM_ALLOMETRIC_RATIO = "LBM_ALLOMETRIC_RATIO"
    RPE_COMPLIANCE_INDEX = "RPE_COMPLIANCE_INDEX"
    TOTAL_ELO_DELTA = "TOTAL_ELO_DELTA"


class RankedTier(str, Enum):
    BRONCE = "Bronce"
    PLATA = "Plata"
    ORO = "Oro"
    PLATINO = "Platino"
    DIAMANTE = "Diamante"
    ELITE = "Élite"


class TeamRole(str, Enum):
    CAPTAIN = "CAPTAIN"
    CO_CAPTAIN = "CO_CAPTAIN"
    MEMBER = "MEMBER"


class TrainingGoal(str, Enum):
    FUERZA = "FUERZA"
    HIPERTROFIA = "HIPERTROFIA"
    RECOMPOSICION = "RECOMPOSICION"


# Coeficientes polinómicos oficiales DOTS
_DOTS_COEFFS_MALE = (
    -0.0000010930,
    0.0007391293,
    -0.1918759221,
    24.0900756,
    -307.75076,
)
_DOTS_COEFFS_FEMALE = (
    -0.0000010706,
    0.0005158568,
    -0.1126655495,
    13.6175032,
    -57.96288,
)


@dataclass(frozen=True)
class SetExecution:
    prescribed_weight_kg: float
    prescribed_reps: int
    prescribed_rpe: float
    actual_weight_kg: float
    actual_reps: int
    actual_rpe: float
    completed: bool
    formula_1rm: Formula1RM = Formula1RM.EPLEY


@dataclass(frozen=True)
class AthleteBiometrics:
    weight_kg: float
    fat_percentage: float
    skeletal_muscle_pct: float
    sex: BiologicalSex
    recovery_score: float
    strain_score: float

    @property
    def lean_body_mass_kg(self) -> float:
        """Masa Magra Libre de Grasa (LBM) en kg."""
        return round(self.weight_kg * (1.0 - (self.fat_percentage / 100.0)), 2)


@dataclass(frozen=True)
class SessionScoreBreakdown:
    raw_volume_kg: float
    dots_coefficient: float
    dots_normalized_volume: float
    lbm_allometric_score: float
    compliance_pct: float
    biometric_consistency_multiplier: float
    elo_delta: int


def estimate_1rm(
    weight_kg: float,
    reps: int,
    rpe: float = 10.0,
    formula: Formula1RM = Formula1RM.EPLEY,
) -> float:
    """
    Calcula el 1RM estimado (Epley, Brzycki, Lombardi, Mayhew) ajustando
    por RIR (Reps In Reserve = 10 - RPE).
    """
    if weight_kg <= 0 or reps <= 0:
        return 0.0
    rir = max(0.0, 10.0 - min(10.0, max(5.0, rpe)))
    effective_reps = reps + rir

    if effective_reps <= 1.0:
        return round(weight_kg, 2)

    if formula == Formula1RM.EPLEY:
        e1rm = weight_kg * (1.0 + (effective_reps / 30.0))
    elif formula == Formula1RM.BRZYCKI:
        denom = max(1.0, 37.0 - min(36.0, effective_reps))
        e1rm = weight_kg * (36.0 / denom)
    elif formula == Formula1RM.LOMBARDI:
        e1rm = weight_kg * math.pow(effective_reps, 0.10)
    else:
        e1rm = (100.0 * weight_kg) / (
            52.2 + 41.9 * math.exp(-0.055 * effective_reps)
        )
    return round(e1rm, 2)


def calculate_dots_coefficient(weight_kg: float, sex: BiologicalSex) -> float:
    """Calcula el coeficiente alométrico DOTS oficial."""
    bw = max(40.0, min(210.0, weight_kg))
    a, b, c, d, e = (
        _DOTS_COEFFS_MALE if sex == BiologicalSex.MALE else _DOTS_COEFFS_FEMALE
    )
    denom = (a * (bw ** 4)) + (b * (bw ** 3)) + (c * (bw ** 2)) + (d * bw) + e
    if denom <= 0:
        return 1.0
    return round(500.0 / denom, 6)


def calculate_lbm_allometric_score(
    sets: Sequence[SetExecution],
    lean_body_mass_kg: float,
) -> float:
    """
    Cálculo de esfuerzo alométrico sobre Masa Magra Libre de Grasa:
    Score_LBM = Sum(w * r * (0.50 + 0.05 * RPE)) / (LBM ^ 0.67)
    """
    lbm_divisor = math.pow(max(25.0, lean_body_mass_kg), 0.67)
    weighted_sum = 0.0
    for s in sets:
        if s.completed and s.actual_weight_kg > 0 and s.actual_reps > 0:
            clamped_rpe = min(10.0, max(1.0, s.actual_rpe))
            weighted_sum += (
                s.actual_weight_kg
                * s.actual_reps
                * (0.50 + 0.05 * clamped_rpe)
            )
    return round(weighted_sum / lbm_divisor, 2)


def resolve_tier(elo: int) -> RankedTier:
    """Mapea el ELO al Tier correspondiente (idéntico al trigger SQL `fn_resolve_elo_tier`)."""
    if elo < 1100:
        return RankedTier.BRONCE
    if elo < 1300:
        return RankedTier.PLATA
    if elo < 1500:
        return RankedTier.ORO
    if elo < 1700:
        return RankedTier.PLATINO
    if elo < 1900:
        return RankedTier.DIAMANTE
    return RankedTier.ELITE


def calculate_session_metrics_and_elo(
    sets: Sequence[SetExecution],
    bio: AthleteBiometrics,
    current_elo: int,
) -> SessionScoreBreakdown:
    """
    Evalúa el volumen bruto, volumen DOTS, Score_LBM, cumplimiento de RPE y Delta ELO.
    """
    if not sets:
        return SessionScoreBreakdown(0.0, 1.0, 0.0, 0.0, 100.0, 1.0, 0)

    raw_volume = 0.0
    compliance_scores: list[float] = []
    executed_rpes: list[float] = []

    for s in sets:
        if not s.completed or s.actual_weight_kg <= 0 or s.actual_reps <= 0:
            compliance_scores.append(0.0)
            continue

        vol = s.actual_weight_kg * s.actual_reps
        raw_volume += vol
        executed_rpes.append(s.actual_rpe)

        prescribed_vol = max(1.0, s.prescribed_weight_kg * s.prescribed_reps)
        work_ratio = min(1.10, vol / prescribed_vol)
        rpe_accuracy = math.exp(-0.15 * abs(s.actual_rpe - s.prescribed_rpe))
        compliance_scores.append(work_ratio * rpe_accuracy)

    dots_coeff = calculate_dots_coefficient(bio.weight_kg, bio.sex)
    dots_volume = round(raw_volume * dots_coeff, 2)
    lbm_score = calculate_lbm_allometric_score(sets, bio.lean_body_mass_kg)

    avg_compliance = sum(compliance_scores) / len(sets)
    avg_rpe = sum(executed_rpes) / len(executed_rpes) if executed_rpes else 0.0

    # Acoplamiento biométrico Recovery vs RPE ejecutado
    bio_mult = 1.0
    if bio.recovery_score < 40.0:
        if avg_rpe <= 7.5 and avg_compliance >= 0.85:
            bio_mult = 1.15
        elif avg_rpe > 8.5:
            bio_mult = 0.80
    elif bio.recovery_score >= 80.0:
        if avg_compliance >= 0.95 and avg_rpe >= 7.5:
            bio_mult = 1.20
    else:
        if 0.90 <= avg_compliance <= 1.05:
            bio_mult = 1.10

    base_k = 18.0 if current_elo < 1500 else (12.0 if current_elo < 1800 else 8.0)
    elo_delta = int(round(base_k * ((avg_compliance * bio_mult) - 0.82)))

    return SessionScoreBreakdown(
        raw_volume_kg=round(raw_volume, 2),
        dots_coefficient=dots_coeff,
        dots_normalized_volume=dots_volume,
        lbm_allometric_score=lbm_score,
        compliance_pct=round(avg_compliance * 100.0, 2),
        biometric_consistency_multiplier=round(bio_mult, 2),
        elo_delta=elo_delta,
    )


def settle_1v1_duel_elo(
    elo_a: int,
    elo_b: int,
    score_a: float,
    score_b: float,
) -> tuple[int, int]:
    """
    Algoritmo ELO dinámico para duelos 1v1 con margen de victoria continuo sobre Score_LBM / DOTS.
    Retorna (delta_elo_a, delta_elo_b).
    """
    expected_a = 1.0 / (1.0 + math.pow(10.0, (elo_b - elo_a) / 400.0))
    expected_b = 1.0 - expected_a

    denom = max(score_a, score_b, 1.0)
    rel_diff = (score_a - score_b) / denom
    actual_a = 1.0 / (1.0 + math.exp(-6.0 * rel_diff))
    actual_b = 1.0 - actual_a

    k_a = 36 if elo_a < 1300 else (24 if elo_a < 1700 else 16)
    k_b = 36 if elo_b < 1300 else (24 if elo_b < 1700 else 16)

    return int(round(k_a * (actual_a - expected_a))), int(round(k_b * (actual_b - expected_b)))
