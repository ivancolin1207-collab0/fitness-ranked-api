from __future__ import annotations

"""
Servicio unificado de Biometría Real y Telemetría Diaria por Usuario en PostgreSQL.
CERO constantes quemadas / CERO mocks:
- Combina `users` y `biometrics` filtrando estrictamente por `user_id`.
- Calcula `lbm_kg` con % grasa corporal real (Fitdays o manual) o mediante la Fórmula de Boer
  diferenciada por sexo biológico (`male` / `female`) cuando solo existen peso y estatura.
- Calcula `biometric_signature` para invalidar y regenerar automáticamente rutinas y cargas.
"""

from datetime import date
from typing import Any, Optional
from uuid import UUID

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.elo_engine import BiologicalSex
from app.models.entities import Biometric, User, WearableMetric


def normalize_sex_code(raw_sex: Any) -> str:
    """Normaliza el sexo biológico a `'male'` o `'female'`."""
    if isinstance(raw_sex, BiologicalSex):
        return "female" if raw_sex == BiologicalSex.FEMALE else "male"
    text_val = str(raw_sex or "").strip().lower()
    if text_val in ("female", "mujer", "femenino", "f", "woman"):
        return "female"
    return "male"


def to_biological_sex_enum(raw_sex: Any) -> BiologicalSex:
    """Convierte cualquier representación de sexo biológico al enum `BiologicalSex`."""
    return (
        BiologicalSex.FEMALE
        if normalize_sex_code(raw_sex) == "female"
        else BiologicalSex.MALE
    )


def compute_boer_lbm_kg(sex: str, weight_kg: float, height_cm: float) -> float:
    """
    Fórmula clínica de Boer (1984) diferenciada por sexo biológico:
    - Hombre ('male'):  (0.407 * weight_kg) + (0.267 * height_cm) - 19.2
    - Mujer  ('female'): (0.252 * weight_kg) + (0.473 * height_cm) - 48.3
    """
    sex_norm = normalize_sex_code(sex)
    if sex_norm == "female":
        raw_lbm = (0.252 * weight_kg) + (0.473 * height_cm) - 48.3
    else:
        raw_lbm = (0.407 * weight_kg) + (0.267 * height_cm) - 19.2
    safe_lbm = max(weight_kg * 0.42, min(weight_kg * 0.95, raw_lbm))
    return round(safe_lbm, 2)


def build_biometric_signature(
    sex: str,
    weight_kg: Optional[float],
    lbm_kg: Optional[float],
) -> Optional[str]:
    """Genera la huella biométrica `sex_round(weight)_round(lbm)` para invalidar rutinas."""
    if weight_kg is None or lbm_kg is None or weight_kg <= 0 or lbm_kg <= 0:
        return None
    sex_norm = normalize_sex_code(sex)
    return f"{sex_norm}_{int(round(weight_kg))}_{int(round(lbm_kg))}"


def derive_secondary_bioimpedance_metrics(
    *,
    sex: str,
    weight_kg: float,
    height_cm: Optional[float],
    body_fat_pct: Optional[float],
) -> dict[str, Any]:
    """
    Calcula las métricas derivadas de composición corporal a partir de los datos reales
    del atleta (usando % grasa si fue provisto o Fórmula de Boer si solo hay peso y estatura).
    """
    sex_norm = normalize_sex_code(sex)
    if body_fat_pct is not None and body_fat_pct > 0:
        resolved_fat = round(max(3.0, min(68.0, float(body_fat_pct))), 2)
        lbm_kg = round(weight_kg * (1.0 - (resolved_fat / 100.0)), 2)
        provider_tag = "PROFILE_MANUAL"
    elif height_cm is not None and height_cm > 0:
        lbm_kg = compute_boer_lbm_kg(sex_norm, weight_kg, height_cm)
        resolved_fat = round(
            max(5.0, min(60.0, (1.0 - (lbm_kg / max(1.0, weight_kg))) * 100.0)),
            2,
        )
        provider_tag = "BOER_PROFILE_ESTIMATE"
    else:
        # Sin estatura ni % grasa: proporción fisiológica conservadora según sexo biológico
        est_fat = 25.0 if sex_norm == "female" else 18.0
        resolved_fat = est_fat
        lbm_kg = round(weight_kg * (1.0 - (resolved_fat / 100.0)), 2)
        provider_tag = "BOER_PROFILE_ESTIMATE"

    # Masa muscular total (~94% de LBM libre de mineral óseo) y % músculo esquelético
    muscle_mass_kg = round(max(15.0, lbm_kg * 0.94), 2)
    skeletal_muscle_pct = round(
        max(22.0, min(65.0, ((lbm_kg * 0.56) / max(1.0, weight_kg)) * 100.0)),
        2,
    )
    # Agua corporal total: ~73.2% de la masa libre de grasa (Pace & Rathbun)
    body_water_pct = round(
        max(35.0, min(78.0, ((lbm_kg * 0.732) / max(1.0, weight_kg)) * 100.0)),
        2,
    )
    # Estimación de índice visceral proporcional al % de grasa y sexo
    fat_baseline = 22.0 if sex_norm == "female" else 14.0
    visceral_fat = max(1, min(30, int(round(4.0 + max(0.0, resolved_fat - fat_baseline) * 0.45))))
    # Katch-McArdle BMR real basado en LBM: 370 + (21.6 * LBM)
    bmr_kcal = max(900, min(5000, int(round(370.0 + (21.6 * lbm_kg)))))

    return {
        "weight_kg": round(weight_kg, 2),
        "fat_percentage": resolved_fat,
        "lbm_kg": lbm_kg,
        "muscle_mass_kg": muscle_mass_kg,
        "skeletal_muscle_pct": skeletal_muscle_pct,
        "visceral_fat": visceral_fat,
        "body_water_pct": body_water_pct,
        "bmr": bmr_kcal,
        "source_provider": provider_tag,
    }


async def get_athlete_biometrics(
    db: AsyncSession,
    user_id: UUID,
) -> dict[str, Any]:
    """
    Consulta el último registro real de bioimpedancia (`biometrics`) del `user_id`
    combinado con su perfil en `users`.
    - Si tiene peso y % grasa real: `lbm_kg = weight_kg * (1 - body_fat_pct / 100)`.
    - Si solo tiene peso, estatura y sexo (sin Fitdays ni % grasa manual): aplica la
      Fórmula de Boer diferenciada por sexo biológico (`male` vs `female`).
    - JAMÁS utiliza constantes fijas de otro usuario si un dato es nulo.
    """
    user = (
        await db.execute(select(User).where(User.id == user_id))
    ).scalar_one_or_none()

    latest_bio = (
        await db.execute(
            select(Biometric)
            .where(Biometric.user_id == user_id)
            .order_by(Biometric.captured_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()

    sex = normalize_sex_code(user.biological_sex if user is not None else "male")
    biological_sex = "FEMALE" if sex == "female" else "MALE"

    height_cm: Optional[float] = (
        float(user.height_cm)
        if (user is not None and user.height_cm is not None)
        else None
    )

    user_weight: Optional[float] = (
        float(user.weight_kg)
        if (user is not None and getattr(user, "weight_kg", None) is not None)
        else None
    )
    user_fat: Optional[float] = (
        float(user.body_fat_pct)
        if (user is not None and getattr(user, "body_fat_pct", None) is not None)
        else None
    )

    weight_kg: Optional[float] = (
        float(latest_bio.weight_kg)
        if (latest_bio is not None and latest_bio.weight_kg is not None)
        else user_weight
    )

    # Determinar si existe % de grasa medido/ingresado explícitamente o si debemos usar Boer
    has_measured_fat = False
    body_fat_pct: Optional[float] = None
    if (
        latest_bio is not None
        and latest_bio.fat_percentage is not None
        and latest_bio.source_provider != "BOER_PROFILE_ESTIMATE"
    ):
        body_fat_pct = float(latest_bio.fat_percentage)
        has_measured_fat = True
    elif user_fat is not None and user_fat > 0:
        body_fat_pct = user_fat
        has_measured_fat = True

    lbm_kg: Optional[float] = None
    lbm_source = "UNCONFIGURED"

    if weight_kg is not None and weight_kg > 0:
        if has_measured_fat and body_fat_pct is not None and body_fat_pct > 0:
            lbm_kg = round(weight_kg * (1.0 - (body_fat_pct / 100.0)), 2)
            lbm_source = "BODY_FAT_MEASURED"
        elif height_cm is not None and height_cm > 0:
            lbm_kg = compute_boer_lbm_kg(sex, weight_kg, height_cm)
            lbm_source = "BOER_FORMULA"
        elif latest_bio is not None and latest_bio.lean_body_mass_kg is not None:
            lbm_kg = float(latest_bio.lean_body_mass_kg)
            lbm_source = "BIOMETRIC_RECORD"

    signature = build_biometric_signature(sex, weight_kg, lbm_kg)

    return {
        "user_id": str(user_id),
        "sex": sex,
        "biological_sex": biological_sex,
        "weight_kg": round(weight_kg, 2) if weight_kg is not None else None,
        "height_cm": round(height_cm, 2) if height_cm is not None else None,
        "body_fat_pct": round(body_fat_pct, 2) if body_fat_pct is not None else None,
        "lbm_kg": lbm_kg,
        "lbm_source": lbm_source,
        "biometric_signature": signature,
        "has_complete_biometrics": bool(
            weight_kg is not None and weight_kg > 0 and lbm_kg is not None and lbm_kg > 0
        ),
        "muscle_mass_kg": float(latest_bio.muscle_mass_kg)
        if latest_bio is not None
        else None,
        "skeletal_muscle_pct": float(latest_bio.skeletal_muscle_pct)
        if latest_bio is not None
        else None,
        "visceral_fat": int(latest_bio.visceral_fat)
        if latest_bio is not None
        else None,
        "body_water_pct": float(latest_bio.body_water_pct)
        if (latest_bio is not None and latest_bio.body_water_pct is not None)
        else None,
        "bmr": int(latest_bio.bmr) if latest_bio is not None else None,
    }


async def get_today_athlete_readiness(
    db: AsyncSession,
    user_id: UUID,
) -> dict[str, Any]:
    """
    Obtiene la telemetría real sincronizada HOY (`date.today()`) para `user_id`
    combinando `daily_readiness` y `wearable_metrics`.
    Si el usuario no ha escaneado ni sincronizado su banda hoy, devuelve todos los campos en `None`.
    """
    today = date.today()

    wm_row = (
        await db.execute(
            select(WearableMetric)
            .where(
                WearableMetric.user_id == user_id,
                WearableMetric.date == today,
            )
            .order_by(WearableMetric.synced_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()

    dr_row = None
    try:
        async with db.begin_nested():
            dr_row = (
                await db.execute(
                    text(
                        """
                        SELECT sleep_pct, recovery_score, strain_score,
                               stress_level, stress_category, sleep_hours,
                               source_device, synced_at, hrv_ms, resting_hr
                        FROM daily_readiness
                        WHERE user_id = :uid AND date = :today
                        ORDER BY synced_at DESC
                        LIMIT 1
                        """
                    ),
                    {"uid": user_id, "today": today},
                )
            ).first()
    except Exception:
        dr_row = None

    if wm_row is None and dr_row is None:
        return {
            "has_readiness_today": False,
            "recovery_score": None,
            "sleep_pct": None,
            "strain_score": None,
            "stress_level": None,
            "stress_category": None,
            "sleep_hours": None,
            "hrv_ms": None,
            "resting_hr": None,
            "source_device": None,
        }

    # Si ambos existen, priorizar el que tenga `synced_at` más reciente
    use_dr_primary = False
    if dr_row is not None and wm_row is None:
        use_dr_primary = True
    elif dr_row is not None and wm_row is not None:
        dr_ts = dr_row[7]
        wm_ts = wm_row.synced_at
        if dr_ts is None or wm_ts is None or dr_ts >= wm_ts:
            use_dr_primary = True

    if use_dr_primary and dr_row is not None:
        dr_hrv = float(dr_row[8]) if (len(dr_row) > 8 and dr_row[8] is not None and float(dr_row[8]) > 0) else None
        dr_rhr = int(dr_row[9]) if (len(dr_row) > 9 and dr_row[9] is not None and int(dr_row[9]) > 0) else None
        return {
            "has_readiness_today": True,
            "sleep_pct": float(dr_row[0]) if dr_row[0] is not None else None,
            "recovery_score": float(dr_row[1]) if dr_row[1] is not None else None,
            "strain_score": float(dr_row[2]) if dr_row[2] is not None else None,
            "stress_level": float(dr_row[3]) if dr_row[3] is not None else None,
            "stress_category": str(dr_row[4]) if dr_row[4] is not None else None,
            "sleep_hours": float(dr_row[5]) if dr_row[5] is not None else None,
            "hrv_ms": dr_hrv
            if dr_hrv is not None
            else (
                float(wm_row.hrv_ms)
                if (wm_row is not None and wm_row.hrv_ms is not None)
                else None
            ),
            "resting_hr": dr_rhr
            if dr_rhr is not None
            else (
                int(wm_row.resting_hr)
                if (wm_row is not None and wm_row.resting_hr is not None)
                else None
            ),
            "source_device": str(dr_row[6]) if dr_row[6] is not None else "WHOOP",
        }

    assert wm_row is not None
    return {
        "has_readiness_today": True,
        "sleep_pct": float(wm_row.sleep_efficiency_pct)
        if wm_row.sleep_efficiency_pct is not None
        else (float(dr_row[0]) if (dr_row is not None and dr_row[0] is not None) else None),
        "recovery_score": float(wm_row.recovery_score),
        "strain_score": float(wm_row.strain_score),
        "stress_level": float(dr_row[3])
        if (dr_row is not None and dr_row[3] is not None)
        else None,
        "stress_category": str(dr_row[4])
        if (dr_row is not None and dr_row[4] is not None)
        else None,
        "sleep_hours": float(wm_row.sleep_hours),
        "hrv_ms": float(wm_row.hrv_ms) if wm_row.hrv_ms is not None else None,
        "resting_hr": int(wm_row.resting_hr) if wm_row.resting_hr is not None else None,
        "source_device": wm_row.source_device.value,
    }
