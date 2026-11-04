from __future__ import annotations

"""
Entidades ORM SQLAlchemy 2.0 sincronizadas con el DDL transaccional en Render PostgreSQL.
"""

from datetime import date, datetime
from typing import Optional
from uuid import UUID

from sqlalchemy import (
    ARRAY,
    Boolean,
    Computed,
    Date,
    DateTime,
    Enum as SAEnum,
    ForeignKey,
    Integer,
    Numeric,
    SmallInteger,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.core.elo_engine import (
    BiologicalSex,
    CompetitionType,
    ExerciseCategory,
    Formula1RM,
    MetricTarget,
    RankedTier,
    TeamRole,
    TrainingGoal,
    UnitSystem,
    WearableSource,
    WorkoutStatus,
)


def _pg_enum(enum_cls, pg_name: str) -> SAEnum:
    return SAEnum(
        enum_cls,
        name=pg_name,
        create_type=False,
        values_callable=lambda obj: [e.value for e in obj],
    )


class User(Base):
    __tablename__ = "users"

    id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    username: Mapped[str] = mapped_column(String(32), unique=True, nullable=False)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(Text, nullable=False)
    full_name: Mapped[Optional[str]] = mapped_column(String(120), nullable=True)
    birth_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    biological_sex: Mapped[BiologicalSex] = mapped_column(
        _pg_enum(BiologicalSex, "biological_sex_enum"),
        nullable=False,
        default=BiologicalSex.MALE,
    )
    height_cm: Mapped[Optional[float]] = mapped_column(Numeric(5, 2), nullable=True)
    training_goal: Mapped[TrainingGoal] = mapped_column(
        _pg_enum(TrainingGoal, "training_goal_enum"),
        nullable=False,
        default=TrainingGoal.HIPERTROFIA,
    )
    preferred_wearable: Mapped[WearableSource] = mapped_column(
        _pg_enum(WearableSource, "wearable_source_enum"),
        nullable=False,
        default=WearableSource.WHOOP,
    )
    unit_system: Mapped[UnitSystem] = mapped_column(
        _pg_enum(UnitSystem, "unit_system_enum"),
        nullable=False,
        default=UnitSystem.KG,
    )
    onboarding_completed: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False
    )
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    biometrics: Mapped[list["Biometric"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    wearable_metrics: Mapped[list["WearableMetric"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    routines: Mapped[list["RoutineTemplate"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    workouts: Mapped[list["Workout"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    ranked_points: Mapped[list["RankedPoint"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )


class Biometric(Base):
    __tablename__ = "biometrics"

    id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    user_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    weight_kg: Mapped[float] = mapped_column(Numeric(5, 2), nullable=False)
    fat_percentage: Mapped[float] = mapped_column(Numeric(4, 2), nullable=False)
    muscle_mass_kg: Mapped[float] = mapped_column(Numeric(5, 2), nullable=False)
    skeletal_muscle_pct: Mapped[float] = mapped_column(Numeric(4, 2), nullable=False)
    visceral_fat: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    body_water_pct: Mapped[Optional[float]] = mapped_column(Numeric(4, 2), nullable=True)
    bmr: Mapped[int] = mapped_column(Integer, nullable=False)
    lean_body_mass_kg: Mapped[float] = mapped_column(
        Numeric(5, 2),
        Computed(
            "ROUND((weight_kg * (1.0 - (fat_percentage / 100.0)))::numeric, 2)",
            persisted=True,
        ),
    )
    ocr_confidence: Mapped[Optional[float]] = mapped_column(
        Numeric(4, 3), nullable=True, default=1.000
    )
    source_provider: Mapped[str] = mapped_column(
        String(50), nullable=False, default="FITDAYS_OCR"
    )
    captured_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    user: Mapped["User"] = relationship(back_populates="biometrics")


class WearableMetric(Base):
    __tablename__ = "wearable_metrics"
    __table_args__ = (
        UniqueConstraint("user_id", "date", "source_device", name="uq_user_date_device"),
    )

    id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    user_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    date: Mapped[date] = mapped_column(Date, nullable=False)
    strain_score: Mapped[float] = mapped_column(Numeric(4, 2), nullable=False)
    recovery_score: Mapped[float] = mapped_column(Numeric(5, 2), nullable=False)
    hrv_ms: Mapped[Optional[float]] = mapped_column(Numeric(5, 2), nullable=True)
    resting_hr: Mapped[Optional[int]] = mapped_column(SmallInteger, nullable=True)
    avg_hr: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    max_hr: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    sleep_hours: Mapped[float] = mapped_column(Numeric(4, 2), nullable=False)
    sleep_efficiency_pct: Mapped[Optional[float]] = mapped_column(
        Numeric(5, 2), nullable=True
    )
    source_device: Mapped[WearableSource] = mapped_column(
        _pg_enum(WearableSource, "wearable_source_enum"), nullable=False
    )
    raw_payload_hash: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    synced_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    user: Mapped["User"] = relationship(back_populates="wearable_metrics")


class Exercise(Base):
    __tablename__ = "exercises"

    id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    name: Mapped[str] = mapped_column(String(120), unique=True, nullable=False)
    muscle_group: Mapped[str] = mapped_column(String(60), nullable=False)
    secondary_muscles: Mapped[list[str]] = mapped_column(
        ARRAY(Text), nullable=False, server_default=text("'{}'")
    )
    category: Mapped[ExerciseCategory] = mapped_column(
        _pg_enum(ExerciseCategory, "exercise_category_enum"), nullable=False
    )
    formula_1rm_type: Mapped[Formula1RM] = mapped_column(
        _pg_enum(Formula1RM, "formula_1rm_enum"),
        nullable=False,
        default=Formula1RM.EPLEY,
    )
    is_compound: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    load_multiplier: Mapped[float] = mapped_column(
        Numeric(3, 2), nullable=False, default=1.00
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class RoutineTemplate(Base):
    __tablename__ = "routine_templates"
    __table_args__ = (
        UniqueConstraint("user_id", "day_of_week", name="uq_user_routine_day"),
    )

    id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    user_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    day_of_week: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    progression_step_kg: Mapped[float] = mapped_column(
        Numeric(4, 2), nullable=False, default=2.50
    )
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    user: Mapped["User"] = relationship(back_populates="routines")
    items: Mapped[list["RoutineTemplateExercise"]] = relationship(
        back_populates="routine",
        cascade="all, delete-orphan",
        order_by="RoutineTemplateExercise.display_order",
    )


class RoutineTemplateExercise(Base):
    __tablename__ = "routine_template_exercises"

    id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    routine_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("routine_templates.id", ondelete="CASCADE"),
        nullable=False,
    )
    exercise_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("exercises.id", ondelete="RESTRICT"),
        nullable=False,
    )
    display_order: Mapped[int] = mapped_column(SmallInteger, nullable=False, default=1)
    target_sets: Mapped[int] = mapped_column(SmallInteger, nullable=False, default=4)
    base_weight_kg: Mapped[float] = mapped_column(
        Numeric(6, 2), nullable=False, default=40.00
    )
    target_reps: Mapped[int] = mapped_column(SmallInteger, nullable=False, default=8)
    target_rpe: Mapped[float] = mapped_column(
        Numeric(3, 1), nullable=False, default=8.0
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    routine: Mapped["RoutineTemplate"] = relationship(back_populates="items")
    exercise: Mapped["Exercise"] = relationship()


class Workout(Base):
    __tablename__ = "workouts"

    id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    user_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    routine_id: Mapped[Optional[UUID]] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("routine_templates.id", ondelete="SET NULL"),
        nullable=True,
    )
    scheduled_for_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    is_rollover: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    date: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    status: Mapped[WorkoutStatus] = mapped_column(
        _pg_enum(WorkoutStatus, "workout_status_enum"),
        nullable=False,
        default=WorkoutStatus.PLANNED,
    )
    readiness_recovery_pct: Mapped[Optional[float]] = mapped_column(
        Numeric(5, 2), nullable=True
    )
    total_volume_kg: Mapped[float] = mapped_column(
        Numeric(10, 2), nullable=False, default=0.00
    )
    dots_normalized_volume: Mapped[float] = mapped_column(
        Numeric(10, 2), nullable=False, default=0.00
    )
    lbm_allometric_score: Mapped[float] = mapped_column(
        Numeric(10, 2), nullable=False, default=0.00
    )
    intensity_rpe: Mapped[Optional[float]] = mapped_column(Numeric(3, 1), nullable=True)
    compliance_pct: Mapped[Optional[float]] = mapped_column(
        Numeric(5, 2), nullable=True, default=100.00
    )
    elo_delta: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    ai_prescription_notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    started_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    completed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    user: Mapped["User"] = relationship(back_populates="workouts")
    sets: Mapped[list["WorkoutSet"]] = relationship(
        back_populates="workout", cascade="all, delete-orphan"
    )


class WorkoutSet(Base):
    __tablename__ = "workout_sets"
    __table_args__ = (
        UniqueConstraint(
            "workout_id", "exercise_id", "set_number", name="uq_workout_exercise_set"
        ),
    )

    id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    workout_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("workouts.id", ondelete="CASCADE"),
        nullable=False,
    )
    exercise_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("exercises.id", ondelete="RESTRICT"),
        nullable=False,
    )
    set_number: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    prescribed_weight: Mapped[float] = mapped_column(Numeric(6, 2), nullable=False)
    prescribed_reps: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    prescribed_rpe: Mapped[float] = mapped_column(
        Numeric(3, 1), nullable=False, default=8.0
    )
    actual_weight: Mapped[Optional[float]] = mapped_column(Numeric(6, 2), nullable=True)
    reps: Mapped[Optional[int]] = mapped_column(SmallInteger, nullable=True)
    rpe: Mapped[Optional[float]] = mapped_column(Numeric(3, 1), nullable=True)
    estimated_1rm_kg: Mapped[Optional[float]] = mapped_column(
        Numeric(6, 2), nullable=True
    )
    completed: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    ai_recalculated: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    completed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    workout: Mapped["Workout"] = relationship(back_populates="sets")
    exercise: Mapped["Exercise"] = relationship()


class Team(Base):
    __tablename__ = "teams"

    id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    name: Mapped[str] = mapped_column(String(80), unique=True, nullable=False)
    tag: Mapped[str] = mapped_column(String(6), unique=True, nullable=False)
    captain_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
    )
    team_elo: Mapped[int] = mapped_column(Integer, nullable=False, default=1200)
    max_members: Mapped[int] = mapped_column(SmallInteger, nullable=False, default=10)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class TeamMember(Base):
    __tablename__ = "team_members"

    team_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("teams.id", ondelete="CASCADE"),
        primary_key=True,
    )
    user_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    role: Mapped[TeamRole] = mapped_column(
        _pg_enum(TeamRole, "team_role_enum"),
        nullable=False,
        default=TeamRole.MEMBER,
    )
    contribution_score: Mapped[float] = mapped_column(
        Numeric(12, 2), nullable=False, default=0.00
    )
    joined_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class Competition(Base):
    __tablename__ = "competitions"

    id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    title: Mapped[str] = mapped_column(String(120), nullable=False)
    type: Mapped[CompetitionType] = mapped_column(
        _pg_enum(CompetitionType, "competition_type_enum"), nullable=False
    )
    metric_target: Mapped[MetricTarget] = mapped_column(
        _pg_enum(MetricTarget, "metric_target_enum"),
        nullable=False,
        default=MetricTarget.LBM_ALLOMETRIC_RATIO,
    )
    season_id: Mapped[str] = mapped_column(String(32), nullable=False)
    start_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    end_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class CompetitionParticipant(Base):
    __tablename__ = "competition_participants"

    id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    competition_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("competitions.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id: Mapped[Optional[UUID]] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=True,
    )
    team_id: Mapped[Optional[UUID]] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("teams.id", ondelete="CASCADE"),
        nullable=True,
    )
    normalized_score: Mapped[float] = mapped_column(
        Numeric(12, 3), nullable=False, default=0.000
    )
    compliance_bonus: Mapped[float] = mapped_column(
        Numeric(8, 3), nullable=False, default=0.000
    )
    biometric_consistency_bonus: Mapped[float] = mapped_column(
        Numeric(8, 3), nullable=False, default=0.000
    )
    final_rank: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    elo_change: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )


class RankedPoint(Base):
    __tablename__ = "ranked_points"
    __table_args__ = (
        UniqueConstraint("user_id", "season_id", name="uq_user_season"),
    )

    id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    user_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    season_id: Mapped[str] = mapped_column(String(32), nullable=False)
    current_elo: Mapped[int] = mapped_column(Integer, nullable=False, default=1200)
    peak_elo: Mapped[int] = mapped_column(Integer, nullable=False, default=1200)
    tier: Mapped[RankedTier] = mapped_column(
        _pg_enum(RankedTier, "ranked_tier_enum"),
        nullable=False,
        default=RankedTier.PLATA,
    )
    wins: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    losses: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    draws: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    active_streak: Mapped[int] = mapped_column(SmallInteger, nullable=False, default=0)
    consistency_multiplier: Mapped[float] = mapped_column(
        Numeric(4, 2), nullable=False, default=1.00
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    user: Mapped["User"] = relationship(back_populates="ranked_points")
