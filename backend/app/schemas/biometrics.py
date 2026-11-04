from __future__ import annotations

"""Esquemas Pydantic v2 para Biometría Dual (Manual + OCR Fitdays) y Wearables (Whoop / Health Connect)."""

from datetime import date, datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.core.elo_engine import WearableSource


class FitdaysExtractedMetrics(BaseModel):
    """Esquema estructurado devuelto por Gemini 2.5 Flash Vision o ingresado en formulario manual."""

    weight_kg: float = Field(..., ge=25.0, le=300.0)
    fat_percentage: float = Field(..., ge=2.0, le=75.0)
    muscle_mass_kg: float = Field(..., ge=10.0, le=180.0)
    skeletal_muscle_pct: float = Field(..., ge=15.0, le=75.0)
    visceral_fat: int = Field(..., ge=1, le=60)
    body_water_pct: float = Field(..., ge=30.0, le=85.0)
    bmr: int = Field(..., ge=600, le=6000)
    ocr_confidence: float = Field(default=1.0, ge=0.0, le=1.0)
    source_provider: str = Field(default="MANUAL_FORM", max_length=50)

    @model_validator(mode="after")
    def verify_muscle_vs_weight(self) -> "FitdaysExtractedMetrics":
        if self.muscle_mass_kg >= self.weight_kg:
            raise ValueError("`muscle_mass_kg` debe ser estrictamente menor que `weight_kg`.")
        return self


class BiometricRecordResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    weight_kg: float
    fat_percentage: float
    muscle_mass_kg: float
    skeletal_muscle_pct: float
    visceral_fat: int
    body_water_pct: Optional[float]
    bmr: int
    lean_body_mass_kg: float
    ocr_confidence: Optional[float]
    source_provider: str
    captured_at: datetime


class WearableSyncRequest(BaseModel):
    date: date
    strain_score: float = Field(..., ge=0.0, le=21.0)
    recovery_score: float = Field(..., ge=0.0, le=100.0)
    hrv_ms: Optional[float] = Field(default=65.0, ge=5.0, le=300.0)
    resting_hr: Optional[int] = Field(default=58, ge=25, le=140)
    avg_hr: int = Field(..., ge=30, le=220)
    max_hr: int = Field(..., ge=40, le=240)
    sleep_hours: float = Field(..., ge=0.0, le=24.0)
    sleep_efficiency_pct: Optional[float] = Field(default=88.0, ge=0.0, le=100.0)
    source_device: WearableSource = WearableSource.WHOOP

    @model_validator(mode="after")
    def verify_heart_rate_bounds(self) -> "WearableSyncRequest":
        if self.max_hr < self.avg_hr:
            raise ValueError("`max_hr` no puede ser menor que `avg_hr`.")
        return self


class WearableSyncResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    date: date
    strain_score: float
    recovery_score: float
    hrv_ms: Optional[float]
    resting_hr: Optional[int]
    avg_hr: int
    max_hr: int
    sleep_hours: float
    sleep_efficiency_pct: Optional[float]
    source_device: WearableSource
    synced_at: datetime
