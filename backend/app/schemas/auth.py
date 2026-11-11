from __future__ import annotations

"""Esquemas Pydantic v2 para Autenticación, Perfil Fisiológico y Onboarding."""

from datetime import date, datetime
from typing import Any, Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field, model_validator

from app.core.elo_engine import (
    BiologicalSex,
    TrainingGoal,
    UnitSystem,
    WearableSource,
)


def mask_email(email: str) -> str:
    """Enmascara el correo electrónico para evitar exposición directa de PII."""
    if "@" not in email:
        return "***"
    local, domain = email.split("@", 1)
    prefix = local[0] if local else "*"
    return f"{prefix}***@{domain}"


def calculate_age_years(birth_date: Optional[date]) -> Optional[int]:
    if birth_date is None:
        return None
    today = date.today()
    years = today.year - birth_date.year - (
        (today.month, today.day) < (birth_date.month, birth_date.day)
    )
    return max(10, min(110, years))


def _normalize_sex_payload(data: Any) -> Any:
    if not isinstance(data, dict):
        return data
    merged = dict(data)
    raw_sex = (
        merged.get("biological_sex")
        or merged.get("sex")
        or merged.get("gender")
    )
    if raw_sex is not None:
        s_low = str(raw_sex).strip().lower()
        if s_low in ("female", "mujer", "femenino", "f", "woman"):
            merged["biological_sex"] = BiologicalSex.FEMALE
        else:
            merged["biological_sex"] = BiologicalSex.MALE

    if "weight" in merged and "weight_kg" not in merged:
        merged["weight_kg"] = merged["weight"]
    if "fat_percentage" in merged and "body_fat_pct" not in merged:
        merged["body_fat_pct"] = merged["fat_percentage"]
    return merged


class UserRegisterRequest(BaseModel):
    username: str = Field(
        ...,
        min_length=3,
        max_length=32,
        pattern=r"^[a-zA-Z0-9_.-]{3,32}$",
    )
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=128)
    full_name: Optional[str] = Field(default=None, max_length=120)
    birth_date: Optional[date] = None
    biological_sex: BiologicalSex = BiologicalSex.MALE
    height_cm: Optional[float] = Field(default=None, ge=100.0, le=250.0)
    weight_kg: Optional[float] = Field(default=None, ge=25.0, le=300.0)
    body_fat_pct: Optional[float] = Field(default=None, ge=2.0, le=70.0)
    training_goal: TrainingGoal = TrainingGoal.HIPERTROFIA
    preferred_wearable: WearableSource = WearableSource.WHOOP
    unit_system: UnitSystem = UnitSystem.KG

    @model_validator(mode="before")
    @classmethod
    def normalize_register_fields(cls, data: Any) -> Any:
        return _normalize_sex_payload(data)


class ProfileSetupUpdateRequest(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=120)
    username: Optional[str] = Field(
        default=None,
        min_length=3,
        max_length=32,
        pattern=r"^[a-zA-Z0-9_.-]{3,32}$",
    )
    birth_date: Optional[date] = None
    biological_sex: BiologicalSex
    height_cm: float = Field(..., ge=100.0, le=250.0)
    weight_kg: Optional[float] = Field(default=None, ge=25.0, le=300.0)
    body_fat_pct: Optional[float] = Field(default=None, ge=2.0, le=70.0)
    training_goal: TrainingGoal = TrainingGoal.HIPERTROFIA
    preferred_wearable: WearableSource = WearableSource.WHOOP
    unit_system: UnitSystem = UnitSystem.KG

    @model_validator(mode="before")
    @classmethod
    def normalize_profile_fields(cls, data: Any) -> Any:
        return _normalize_sex_payload(data)


class UserLoginRequest(BaseModel):
    username_or_email: str = Field(..., min_length=3, max_length=255)
    password: str = Field(..., min_length=8, max_length=128)


class PasswordResetDirectRequest(BaseModel):
    email: str = Field(
        ...,
        min_length=3,
        max_length=255,
        description="Correo electrónico o username verificado del atleta",
    )
    new_password: str = Field(..., min_length=8, max_length=128)


class UserProfileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    username: str
    full_name: Optional[str] = None
    masked_email: str
    birth_date: Optional[date] = None
    age_years: Optional[int] = None
    biological_sex: BiologicalSex
    sex: str = "male"
    height_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    body_fat_pct: Optional[float] = None
    lbm_kg: Optional[float] = None
    biometric_signature: Optional[str] = None
    training_goal: TrainingGoal = TrainingGoal.HIPERTROFIA
    preferred_wearable: WearableSource = WearableSource.WHOOP
    unit_system: UnitSystem
    onboarding_completed: bool = False
    current_elo: int = 1200
    current_tier: str = "Plata"
    is_active: bool
    created_at: datetime


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserProfileResponse
