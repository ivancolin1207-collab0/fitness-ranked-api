from __future__ import annotations

"""Esquemas Pydantic v2 para Biometría Dual (Manual + OCR Fitdays) y Wearables (Whoop / Health Connect / Multi-Marca)."""

from datetime import date, datetime
from typing import Any, Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.core.elo_engine import WearableSource


class FitdaysExtractedMetrics(BaseModel):
    """Esquema estructurado devuelto por Gemini 2.5 Flash Vision o ingresado en formulario manual."""

    weight_kg: float = Field(..., ge=20.0, le=350.0)
    body_fat_pct: Optional[float] = Field(default=None, ge=1.0, le=80.0)
    fat_percentage: float = Field(..., ge=1.0, le=80.0)
    muscle_mass_kg: Optional[float] = Field(default=None, ge=5.0, le=220.0)
    skeletal_muscle_pct: Optional[float] = Field(default=None, ge=5.0, le=85.0)
    visceral_fat: Optional[float] = Field(default=None, ge=0.5, le=60.0)
    water_pct: Optional[float] = Field(default=None, ge=20.0, le=90.0)
    body_water_pct: Optional[float] = Field(default=None, ge=20.0, le=90.0)
    bmr_kcal: Optional[int] = Field(default=None, ge=500, le=7000)
    bmr: Optional[int] = Field(default=None, ge=500, le=7000)
    ocr_confidence: float = Field(default=1.0, ge=0.0, le=1.0)
    source_provider: str = Field(default="FITDAYS_OCR", max_length=50)

    @model_validator(mode="before")
    @classmethod
    def normalize_fitdays_keys(cls, data: object) -> object:
        if not isinstance(data, dict):
            return data
        merged = dict(data)
        if "body_fat_pct" in merged and "fat_percentage" not in merged:
            merged["fat_percentage"] = merged["body_fat_pct"]
        elif "fat_percentage" in merged and "body_fat_pct" not in merged:
            merged["body_fat_pct"] = merged["fat_percentage"]

        if "water_pct" in merged and "body_water_pct" not in merged:
            merged["body_water_pct"] = merged["water_pct"]
        elif "body_water_pct" in merged and "water_pct" not in merged:
            merged["water_pct"] = merged["body_water_pct"]

        if (
            "bmr_kcal" in merged
            and merged["bmr_kcal"] is not None
            and "bmr" not in merged
        ):
            merged["bmr"] = int(round(float(merged["bmr_kcal"])))
        elif "bmr" in merged and merged["bmr"] is not None and "bmr_kcal" not in merged:
            merged["bmr_kcal"] = int(round(float(merged["bmr"])))
        return merged

    @model_validator(mode="after")
    def sync_alias_fields(self) -> "FitdaysExtractedMetrics":
        if self.body_fat_pct is None:
            self.body_fat_pct = self.fat_percentage
        if self.water_pct is None and self.body_water_pct is not None:
            self.water_pct = self.body_water_pct
        if self.bmr_kcal is None and self.bmr is not None:
            self.bmr_kcal = self.bmr
        return self


class BiometricRecordResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    weight_kg: float
    fat_percentage: float
    muscle_mass_kg: float
    skeletal_muscle_pct: float
    visceral_fat: float
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
    hrv_ms: Optional[float] = Field(default=None, ge=0.0, le=300.0)
    resting_hr: Optional[int] = Field(default=None, ge=0, le=200)
    avg_hr: int = Field(default=60, ge=0, le=220)
    max_hr: int = Field(default=80, ge=0, le=240)
    sleep_hours: float = Field(..., ge=0.0, le=24.0)
    sleep_efficiency_pct: Optional[float] = Field(default=None, ge=0.0, le=100.0)
    stress_level: Optional[float] = Field(default=None, ge=0.0, le=3.0)
    stress_category: Optional[str] = Field(default=None, max_length=25)
    source_device: WearableSource = WearableSource.WHOOP

    @model_validator(mode="after")
    def verify_heart_rate_bounds(self) -> "WearableSyncRequest":
        if self.max_hr < self.avg_hr:
            self.max_hr = max(self.avg_hr, 40)
        return self


class WhoopScanBase64Request(BaseModel):
    image_base64: str = Field(..., min_length=32)
    mime_type: str = Field(default="image/jpeg")
    source_device: str = Field(default="WHOOP")
    source_wearable: Optional[str] = None


class WearableSyncResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    date: date
    strain_score: float
    recovery_score: float
    hrv_ms: Optional[float] = None
    resting_hr: Optional[int] = None
    avg_hr: int = 0
    max_hr: int = 0
    sleep_hours: float = 0.0
    sleep_efficiency_pct: Optional[float] = None
    sleep_pct: Optional[float] = None
    stress_level: Optional[float] = None
    stress_category: Optional[str] = None
    whoop_stress_level: Optional[float] = None
    source_device: WearableSource = WearableSource.WHOOP
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
    sleep_pct: float = Field(..., ge=0.0, le=100.0)
    sleep_performance_pct: float = Field(..., ge=0.0, le=100.0)
    recovery_score: float = Field(..., ge=0.0, le=100.0)
    strain_score: float = Field(..., ge=0.0, le=21.0)
    stress_level: float = Field(default=0.0, ge=0.0, le=3.0)
    stress_category: str = Field(default="SIN DATO")
    sleep_hours: float = Field(default=0.0, ge=0.0, le=24.0)
    resting_hr: int = Field(default=0, ge=0, le=220)
    hrv_ms: float = Field(default=0.0, ge=0.0, le=300.0)
    trusleep_score: int = Field(default=0, ge=0, le=100)
    stress_score: int = Field(default=0, ge=0, le=100)
    avg_heart_rate: int = Field(default=0, ge=0, le=240)
    vo2max: float = Field(default=0.0, ge=0.0, le=95.0)
    energy_score: int = Field(default=0, ge=0, le=100)
    sleep_duration_hours: float = Field(default=0.0, ge=0.0, le=24.0)
    bia_muscle_pct: float = Field(default=0.0, ge=0.0, le=75.0)
    bia_fat_pct: float = Field(default=0.0, ge=0.0, le=70.0)


class WhoopScreenScanResponse(BaseModel):
    status: str = "success"
    data: Optional[dict[str, Any]] = None
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
    whoop_health_metrics_in_range: int = 0
    resting_hr: int = 0
    hrv_ms: float = 0.0
    avg_hr: int = 0
    max_hr: int = 0
    sleep_hours: float = 0.0
    sleep_efficiency_pct: float = 0.0
    huawei_trusleep_score: int = 0
    huawei_stress_score: int = 0
    huawei_vo2_max: float = 0.0
    samsung_energy_score: int = 0
    samsung_bia_muscle_pct: float = 0.0
    samsung_bia_fat_pct: float = 0.0
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
