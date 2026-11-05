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


class HydrationLogEntrySchema(BaseModel):
    amount_ml: int
    timestamp_label: str
    recorded_at: str


class HydrationAddRequest(BaseModel):
    amount_ml: int = Field(..., ge=50, le=5000)
    timestamp_label: Optional[str] = None


class HydrationTodayResponse(BaseModel):
    date: str
    total_ml: int
    target_ml: int
    progress_pct: float
    logs: list[HydrationLogEntrySchema] = Field(default_factory=list)


class WhoopScreenExtractedMetrics(BaseModel):
    sleep_pct: float = Field(default=80.0, ge=0.0, le=100.0)
    sleep_performance_pct: float = Field(default=80.0, ge=0.0, le=100.0)
    recovery_score: float = Field(default=47.0, ge=0.0, le=100.0)
    strain_score: float = Field(default=7.2, ge=0.0, le=21.0)
    stress_level: float = Field(default=2.4, ge=0.0, le=3.0)
    stress_category: str = Field(default="ALTO")
    resting_hr: int = Field(default=58, ge=25, le=140)
    hrv_ms: float = Field(default=64.0, ge=5.0, le=300.0)
    trusleep_score: int = Field(default=84, ge=0, le=100)
    stress_score: int = Field(default=42, ge=0, le=100)
    avg_heart_rate: int = Field(default=68, ge=30, le=220)
    vo2max: float = Field(default=52.0, ge=15.0, le=95.0)
    energy_score: int = Field(default=78, ge=0, le=100)
    sleep_duration_hours: float = Field(default=7.2, ge=0.0, le=24.0)
    bia_muscle_pct: float = Field(default=43.8, ge=10.0, le=75.0)
    bia_fat_pct: float = Field(default=13.8, ge=2.0, le=70.0)


class WhoopScreenScanResponse(BaseModel):
    id: UUID
    user_id: UUID
    date: date
    sleep_pct: float
    sleep_performance_pct: float
    recovery_score: float
    strain_score: float
    stress_level: float
    stress_category: str
    whoop_stress_level: float
    whoop_health_metrics_in_range: int = 5
    resting_hr: int
    hrv_ms: float
    avg_hr: int
    max_hr: int
    sleep_hours: float
    sleep_efficiency_pct: float
    huawei_trusleep_score: int = 84
    huawei_stress_score: int = 42
    huawei_vo2_max: float = 52.0
    samsung_energy_score: int = 78
    samsung_bia_muscle_pct: float = 43.8
    samsung_bia_fat_pct: float = 13.8
    source_device: WearableSource = WearableSource.WHOOP
    synced_at: datetime


class AiCoachChatMessageItem(BaseModel):
    role: str = Field(default="user")
    content: str


class AiCoachChatRequest(BaseModel):
    model_config = ConfigDict(extra="allow")

    message: str = Field(..., min_length=1, max_length=2000)
    history: list[AiCoachChatMessageItem] = Field(default_factory=list)
    athlete_context: Optional[dict] = None
    athlete_name: Optional[str] = None
    recovery_score: Optional[float] = None
    sleep_performance_pct: Optional[float] = None
    strain_score: Optional[float] = None
    stress_level: Optional[float] = None
    stress_category: Optional[str] = None
    hydration_consumed_ml: Optional[int] = None
    hydration_goal_ml: Optional[int] = None
    scheduled_routine_name: Optional[str] = None


class AiCoachChatResponse(BaseModel):
    reply: str
    readiness_zone: str
    suggested_prompts: list[str] = Field(default_factory=list)
    generated_at: datetime
