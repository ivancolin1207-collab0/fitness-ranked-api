from __future__ import annotations

"""Esquemas Pydantic v2 para Rutinas Semanales, Rollover, Entrenamientos y Prescripción Gemini."""

from datetime import date, datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.core.elo_engine import ExerciseCategory, Formula1RM, WorkoutStatus


class ExerciseCreateRequest(BaseModel):
    name: str = Field(..., min_length=2, max_length=120)
    muscle_group: str = Field(..., min_length=2, max_length=60)
    secondary_muscles: list[str] = Field(default_factory=list)
    category: ExerciseCategory = ExerciseCategory.FUERZA
    formula_1rm_type: Formula1RM = Formula1RM.EPLEY
    is_compound: bool = True
    load_multiplier: float = Field(default=1.0, ge=0.1, le=2.0)


class RoutineExerciseInput(BaseModel):
    exercise_name: str = Field(..., min_length=2, max_length=120)
    muscle_group: str = Field(default="General", min_length=2, max_length=60)
    category: ExerciseCategory = ExerciseCategory.FUERZA
    target_sets: int = Field(default=4, ge=1, le=20)
    base_weight_kg: float = Field(default=60.0, ge=0.0, le=600.0)
    target_reps: int = Field(default=8, ge=1, le=100)
    target_rpe: float = Field(default=8.0, ge=5.0, le=10.0)


class RoutineTemplateUpsertRequest(BaseModel):
    name: str = Field(..., min_length=2, max_length=120)
    day_of_week: int = Field(..., ge=1, le=7)
    progression_step_kg: float = Field(default=2.5, ge=0.0, le=20.0)
    exercises: list[RoutineExerciseInput] = Field(..., min_length=1, max_length=15)


class RoutineExerciseItemResponse(BaseModel):
    exercise_id: UUID
    exercise_name: str
    muscle_group: str
    display_order: int
    target_sets: int
    base_weight_kg: float
    recommended_weight_kg: float
    progressive_overload_applied: bool = False
    target_reps: int
    target_rpe: float


class RoutineTemplateResponse(BaseModel):
    id: UUID
    name: str
    day_of_week: int
    progression_step_kg: float
    is_active: bool
    exercises: list[RoutineExerciseItemResponse]


class TodayWorkoutPlanResponse(BaseModel):
    has_routines: bool
    is_rollover: bool = False
    rollover_from_day: Optional[int] = None
    coach_rollover_banner: Optional[str] = None
    active_routine: Optional[RoutineTemplateResponse] = None
    active_workout: Optional["WorkoutSessionResponse"] = None


class PlannedExerciseInput(BaseModel):
    exercise_id: UUID
    sets_count: int = Field(default=4, ge=1, le=20)
    base_weight_kg: float = Field(..., ge=0.0, le=600.0)
    target_reps: int = Field(default=8, ge=1, le=100)
    target_rpe: float = Field(default=8.0, ge=5.0, le=10.0)


class WorkoutStartRequest(BaseModel):
    routine_id: Optional[UUID] = None
    is_rollover: bool = False
    scheduled_for_date: Optional[date] = None
    exercises: list[PlannedExerciseInput] = Field(..., min_length=1, max_length=25)


class PrescribedSetItem(BaseModel):
    set_number: int = Field(..., ge=1, le=50)
    prescribed_weight_kg: float = Field(..., ge=0.0, le=600.0)
    prescribed_reps: int = Field(..., ge=1, le=100)
    prescribed_rpe: float = Field(..., ge=5.0, le=10.0)
    rest_seconds: int = Field(default=150, ge=30, le=600)


class AdaptivePrescriptionResponse(BaseModel):
    readiness_zone: str = Field(
        ..., pattern="^(RED_DELOAD|YELLOW_MAINTENANCE|GREEN_OVERLOAD)$"
    )
    adjustment_rationale: str = Field(..., max_length=280)
    safety_guardrail_triggered: bool = False
    updated_sets: list[PrescribedSetItem]


class WorkoutSetDetailResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    exercise_id: UUID
    exercise_name: str = "Ejercicio"
    set_number: int
    prescribed_weight: float
    prescribed_reps: int
    prescribed_rpe: float
    actual_weight: Optional[float]
    reps: Optional[int]
    rpe: Optional[float]
    estimated_1rm_kg: Optional[float]
    completed: bool
    ai_recalculated: bool


class WorkoutSessionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    routine_id: Optional[UUID] = None
    is_rollover: bool = False
    date: datetime
    status: WorkoutStatus
    readiness_recovery_pct: Optional[float]
    total_volume_kg: float
    dots_normalized_volume: float
    lbm_allometric_score: float
    compliance_pct: Optional[float]
    elo_delta: int
    ai_prescription_notes: Optional[str]
    sets: list[WorkoutSetDetailResponse]


class SetExecutionFeedbackRequest(BaseModel):
    exercise_id: UUID
    set_number: int = Field(..., ge=1, le=50)
    completed_binary_ui: bool = Field(
        ...,
        description="Confirmación binaria UI: '¿Completaste con este peso? [SÍ / NO]'",
    )
    actual_weight_kg: float = Field(..., ge=0.0, le=600.0)
    actual_reps: int = Field(..., ge=0, le=200)
    actual_rpe: float = Field(..., ge=1.0, le=10.0)


class SetExecutionFeedbackResponse(BaseModel):
    workout_id: UUID
    exercise_id: UUID
    set_number: int
    estimated_1rm_kg: float
    session_raw_volume_kg: float
    session_dots_volume: float
    session_lbm_allometric_score: float
    compliance_pct: float
    projected_elo_delta: int
    current_elo: int
    current_tier: str
    workout_completed: bool = False
    gemini_prescription: AdaptivePrescriptionResponse
