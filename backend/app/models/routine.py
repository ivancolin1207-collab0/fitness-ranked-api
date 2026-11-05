from __future__ import annotations

"""
Modelos relacionales PostgreSQL para la periodización dinámica de 5 días x 6 ejercicios
generada por Gemini 2.5 Flash (`UserRoutine`, `WorkoutDay`, `WorkoutExercise`).
"""

from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import (
    ARRAY,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class UserRoutine(Base):
    __tablename__ = "user_routines"

    id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        server_default=text("gen_random_uuid()"),
    )
    user_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(180), nullable=False)
    weekly_focus: Mapped[str] = mapped_column(
        String(240),
        nullable=False,
        default="Enfoque biomecánico adaptado a LBM",
    )
    generated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    status: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default="active",
        server_default=text("'active'"),
    )

    days: Mapped[list["WorkoutDay"]] = relationship(
        "WorkoutDay",
        back_populates="routine",
        cascade="all, delete-orphan",
        order_by="WorkoutDay.day_number",
    )


class WorkoutDay(Base):
    __tablename__ = "workout_days"

    id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        server_default=text("gen_random_uuid()"),
    )
    routine_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("user_routines.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    day_number: Mapped[int] = mapped_column(Integer, nullable=False)
    day_name: Mapped[str] = mapped_column(String(140), nullable=False)
    target_muscles: Mapped[list[str]] = mapped_column(
        ARRAY(String(60)),
        nullable=False,
        default=list,
    )

    routine: Mapped["UserRoutine"] = relationship(
        "UserRoutine",
        back_populates="days",
    )
    exercises: Mapped[list["WorkoutExercise"]] = relationship(
        "WorkoutExercise",
        back_populates="day",
        cascade="all, delete-orphan",
        order_by="WorkoutExercise.order",
    )


class WorkoutExercise(Base):
    __tablename__ = "workout_exercises"

    id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        server_default=text("gen_random_uuid()"),
    )
    day_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("workout_days.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    order: Mapped[int] = mapped_column(Integer, nullable=False)
    exercise_key: Mapped[str] = mapped_column(
        String(80),
        nullable=False,
        default="bench_press_barbell",
    )
    name: Mapped[str] = mapped_column(String(140), nullable=False)
    muscle_group: Mapped[str] = mapped_column(String(80), nullable=False)
    sets: Mapped[int] = mapped_column(Integer, nullable=False, default=4)
    reps: Mapped[str] = mapped_column(String(30), nullable=False, default="8-10")
    prescribed_weight_kg: Mapped[float] = mapped_column(
        Numeric(6, 2),
        nullable=False,
        default=40.0,
    )
    rpe: Mapped[float] = mapped_column(
        Numeric(3, 1),
        nullable=False,
        default=8.0,
    )
    rest_seconds: Mapped[int] = mapped_column(Integer, nullable=False, default=90)
    tempo: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default="3-0-1-0",
    )
    coaching_cue: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        default="Controla la fase excéntrica y mantén estabilidad escapular",
    )

    day: Mapped["WorkoutDay"] = relationship(
        "WorkoutDay",
        back_populates="exercises",
    )
