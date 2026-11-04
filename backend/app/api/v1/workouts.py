from __future__ import annotations

"""
Endpoints de Rutinas Semanales, Lógica de Asistencia y Arrastre (Rollover),
Entrenamientos en Vivo y Prescripción Adaptativa Gemini (`/workouts`).
"""

from datetime import date, datetime, timedelta, timezone
from typing import Annotated, Any, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import delete, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import get_settings
from app.core.database import get_db
from app.core.elo_engine import (
    AthleteBiometrics,
    Formula1RM,
    RankedTier,
    SetExecution,
    WorkoutStatus,
    calculate_session_metrics_and_elo,
    estimate_1rm,
    resolve_tier,
)
from app.core.security import get_current_user
from app.models.entities import (
    Biometric,
    Exercise,
    RankedPoint,
    RoutineTemplate,
    RoutineTemplateExercise,
    User,
    WearableMetric,
    Workout,
    WorkoutSet,
)
from app.schemas.workouts import (
    ExerciseCreateRequest,
    RoutineExerciseItemResponse,
    RoutineTemplateResponse,
    RoutineTemplateUpsertRequest,
    SetExecutionFeedbackRequest,
    SetExecutionFeedbackResponse,
    TodayWorkoutPlanResponse,
    WorkoutSessionResponse,
    WorkoutSetDetailResponse,
    WorkoutStartRequest,
)
from app.services.gemini_service import (
    generate_adaptive_prescription,
    round_to_plate_increment,
)

router = APIRouter(prefix="/workouts", tags=["Workouts, Routines & Adaptive Coach"])


async def _compute_recommended_weight_for_exercise(
    db: AsyncSession,
    user_id: UUID,
    exercise_id: UUID,
    base_weight_kg: float,
    target_rpe: float,
    progression_step_kg: float,
) -> tuple[float, bool]:
    """
    Evalúa el rendimiento de la última sesión completada para este ejercicio.
    Si el usuario completó sus series a un RPE medio <= target_rpe con peso >= base_weight_kg,
    aplica sobrecarga progresiva semanal (+progression_step_kg).
    """
    stmt = (
        select(WorkoutSet)
        .join(Workout, Workout.id == WorkoutSet.workout_id)
        .where(
            Workout.user_id == user_id,
            Workout.status == WorkoutStatus.COMPLETED,
            WorkoutSet.exercise_id == exercise_id,
            WorkoutSet.completed.is_(True),
        )
        .order_by(Workout.date.desc(), WorkoutSet.set_number.asc())
        .limit(4)
    )
    recent_sets = (await db.execute(stmt)).scalars().all()
    if not recent_sets:
        return round_to_plate_increment(base_weight_kg), False

    avg_actual_w = sum(float(s.actual_weight or base_weight_kg) for s in recent_sets) / len(
        recent_sets
    )
    avg_actual_rpe = sum(float(s.rpe or target_rpe) for s in recent_sets) / len(
        recent_sets
    )

    if avg_actual_w >= base_weight_kg and avg_actual_rpe <= target_rpe + 0.3:
        recommended = round_to_plate_increment(
            max(base_weight_kg, avg_actual_w) + progression_step_kg
        )
        return recommended, True

    return round_to_plate_increment(max(base_weight_kg, avg_actual_w)), False


async def _build_routine_response(
    db: AsyncSession,
    routine: RoutineTemplate,
    user_id: UUID,
) -> RoutineTemplateResponse:
    items_out: list[RoutineExerciseItemResponse] = []
    step_kg = float(routine.progression_step_kg)

    for item in routine.items:
        base_w = float(item.base_weight_kg)
        rec_w, overloaded = await _compute_recommended_weight_for_exercise(
            db=db,
            user_id=user_id,
            exercise_id=item.exercise_id,
            base_weight_kg=base_w,
            target_rpe=float(item.target_rpe),
            progression_step_kg=step_kg,
        )
        items_out.append(
            RoutineExerciseItemResponse(
                exercise_id=item.exercise_id,
                exercise_name=item.exercise.name,
                muscle_group=item.exercise.muscle_group,
                display_order=int(item.display_order),
                target_sets=int(item.target_sets),
                base_weight_kg=base_w,
                recommended_weight_kg=rec_w,
                progressive_overload_applied=overloaded,
                target_reps=int(item.target_reps),
                target_rpe=float(item.target_rpe),
            )
        )

    return RoutineTemplateResponse(
        id=routine.id,
        name=routine.name,
        day_of_week=int(routine.day_of_week),
        progression_step_kg=step_kg,
        is_active=bool(routine.is_active),
        exercises=items_out,
    )


def _to_workout_session_response(workout: Workout) -> WorkoutSessionResponse:
    sets_out = [
        WorkoutSetDetailResponse(
            id=s.id,
            exercise_id=s.exercise_id,
            exercise_name=s.exercise.name if s.exercise else "Ejercicio",
            set_number=int(s.set_number),
            prescribed_weight=float(s.prescribed_weight),
            prescribed_reps=int(s.prescribed_reps),
            prescribed_rpe=float(s.prescribed_rpe),
            actual_weight=float(s.actual_weight) if s.actual_weight is not None else None,
            reps=int(s.reps) if s.reps is not None else None,
            rpe=float(s.rpe) if s.rpe is not None else None,
            estimated_1rm_kg=float(s.estimated_1rm_kg)
            if s.estimated_1rm_kg is not None
            else None,
            completed=bool(s.completed),
            ai_recalculated=bool(s.ai_recalculated),
        )
        for s in sorted(workout.sets, key=lambda x: (x.exercise_id, x.set_number))
    ]
    return WorkoutSessionResponse(
        id=workout.id,
        user_id=workout.user_id,
        routine_id=workout.routine_id,
        is_rollover=bool(workout.is_rollover),
        date=workout.date,
        status=workout.status,
        readiness_recovery_pct=float(workout.readiness_recovery_pct)
        if workout.readiness_recovery_pct is not None
        else None,
        total_volume_kg=float(workout.total_volume_kg),
        dots_normalized_volume=float(workout.dots_normalized_volume),
        lbm_allometric_score=float(workout.lbm_allometric_score),
        compliance_pct=float(workout.compliance_pct)
        if workout.compliance_pct is not None
        else None,
        elo_delta=int(workout.elo_delta),
        ai_prescription_notes=workout.ai_prescription_notes,
        sets=sets_out,
    )


@router.get("/exercises", status_code=status.HTTP_200_OK)
async def list_exercises(
    _current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> list[dict[str, Any]]:
    rows = (
        await db.execute(select(Exercise).order_by(Exercise.muscle_group, Exercise.name))
    ).scalars().all()
    return [
        {
            "id": ex.id,
            "name": ex.name,
            "muscle_group": ex.muscle_group,
            "category": ex.category.value,
            "formula_1rm_type": ex.formula_1rm_type.value,
        }
        for ex in rows
    ]


@router.post("/exercises", status_code=status.HTTP_201_CREATED)
async def create_exercise(
    payload: ExerciseCreateRequest,
    _current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, Any]:
    existing = (
        await db.execute(select(Exercise).where(Exercise.name == payload.name.strip()))
    ).scalar_one_or_none()
    if existing is not None:
        return {
            "id": existing.id,
            "name": existing.name,
            "muscle_group": existing.muscle_group,
            "category": existing.category.value,
            "formula_1rm_type": existing.formula_1rm_type.value,
        }

    ex = Exercise(
        name=payload.name.strip(),
        muscle_group=payload.muscle_group.strip(),
        secondary_muscles=payload.secondary_muscles,
        category=payload.category,
        formula_1rm_type=payload.formula_1rm_type,
        is_compound=payload.is_compound,
        load_multiplier=payload.load_multiplier,
    )
    db.add(ex)
    await db.commit()
    await db.refresh(ex)
    return {
        "id": ex.id,
        "name": ex.name,
        "muscle_group": ex.muscle_group,
        "category": ex.category.value,
        "formula_1rm_type": ex.formula_1rm_type.value,
    }


@router.get(
    "/routines",
    response_model=list[RoutineTemplateResponse],
    status_code=status.HTTP_200_OK,
)
async def list_user_routines(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> list[RoutineTemplateResponse]:
    stmt = (
        select(RoutineTemplate)
        .options(
            selectinload(RoutineTemplate.items).selectinload(
                RoutineTemplateExercise.exercise
            )
        )
        .where(
            RoutineTemplate.user_id == current_user.id,
            RoutineTemplate.is_active.is_(True),
        )
        .order_by(RoutineTemplate.day_of_week.asc())
    )
    routines = (await db.execute(stmt)).scalars().all()
    out: list[RoutineTemplateResponse] = []
    for r in routines:
        out.append(await _build_routine_response(db, r, current_user.id))
    return out


@router.post(
    "/routines",
    response_model=RoutineTemplateResponse,
    status_code=status.HTTP_201_CREATED,
)
async def upsert_user_routine(
    payload: RoutineTemplateUpsertRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> RoutineTemplateResponse:
    """
    Crea o actualiza la rutina asignada a un día de la semana (`1 = Lunes ... 7 = Domingo`)
    con sus ejercicios, series, pesos base y RPE objetivo.
    """
    existing = (
        await db.execute(
            select(RoutineTemplate).where(
                RoutineTemplate.user_id == current_user.id,
                RoutineTemplate.day_of_week == payload.day_of_week,
            )
        )
    ).scalar_one_or_none()

    if existing is None:
        routine = RoutineTemplate(
            user_id=current_user.id,
            name=payload.name.strip(),
            day_of_week=payload.day_of_week,
            progression_step_kg=payload.progression_step_kg,
            is_active=True,
        )
        db.add(routine)
        await db.flush()
    else:
        routine = existing
        routine.name = payload.name.strip()
        routine.progression_step_kg = payload.progression_step_kg
        routine.is_active = True
        await db.execute(
            delete(RoutineTemplateExercise).where(
                RoutineTemplateExercise.routine_id == routine.id
            )
        )
        await db.flush()

    for idx, ex_in in enumerate(payload.exercises, start=1):
        clean_name = ex_in.exercise_name.strip()
        ex_obj = (
            await db.execute(select(Exercise).where(Exercise.name == clean_name))
        ).scalar_one_or_none()
        if ex_obj is None:
            ex_obj = Exercise(
                name=clean_name,
                muscle_group=ex_in.muscle_group.strip(),
                category=ex_in.category,
                formula_1rm_type=Formula1RM.EPLEY,
                is_compound=True,
            )
            db.add(ex_obj)
            await db.flush()

        db.add(
            RoutineTemplateExercise(
                routine_id=routine.id,
                exercise_id=ex_obj.id,
                display_order=idx,
                target_sets=ex_in.target_sets,
                base_weight_kg=ex_in.base_weight_kg,
                target_reps=ex_in.target_reps,
                target_rpe=ex_in.target_rpe,
            )
        )

    await db.commit()

    reloaded = (
        await db.execute(
            select(RoutineTemplate)
            .options(
                selectinload(RoutineTemplate.items).selectinload(
                    RoutineTemplateExercise.exercise
                )
            )
            .where(RoutineTemplate.id == routine.id)
        )
    ).scalar_one()
    return await _build_routine_response(db, reloaded, current_user.id)


@router.get(
    "/today-plan",
    response_model=TodayWorkoutPlanResponse,
    status_code=status.HTTP_200_OK,
)
async def get_today_workout_plan(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> TodayWorkoutPlanResponse:
    """
    Evalúa la asistencia del usuario y aplica la lógica de Arrastre de Días (Rollover):
    - Si existe una sesión `IN_PROGRESS` hoy, la devuelve directamente para continuar.
    - Si el día programado anterior (ayer o antes en la semana actual) NO tiene un workout
      con `status == 'COMPLETED'`, arrastra esa rutina pendiente para hoy con el aviso:
      'No se registró sesión ayer. Tu rutina pendiente [Nombre de la Rutina] pasa para hoy.'
    """
    today = date.today()
    today_iso_day = today.isoweekday()  # 1 (Lunes) .. 7 (Domingo)
    yesterday = today - timedelta(days=1)
    yesterday_iso_day = yesterday.isoweekday()

    # 1. Verificar si ya hay un workout en progreso hoy
    active_workout_stmt = (
        select(Workout)
        .options(selectinload(Workout.sets).selectinload(WorkoutSet.exercise))
        .where(
            Workout.user_id == current_user.id,
            Workout.status == WorkoutStatus.IN_PROGRESS,
        )
        .order_by(Workout.date.desc())
        .limit(1)
    )
    in_progress_workout = (await db.execute(active_workout_stmt)).scalar_one_or_none()

    # 2. Cargar todas las rutinas activas del usuario
    routines_stmt = (
        select(RoutineTemplate)
        .options(
            selectinload(RoutineTemplate.items).selectinload(
                RoutineTemplateExercise.exercise
            )
        )
        .where(
            RoutineTemplate.user_id == current_user.id,
            RoutineTemplate.is_active.is_(True),
        )
        .order_by(RoutineTemplate.day_of_week.asc())
    )
    routines = (await db.execute(routines_stmt)).scalars().all()
    if not routines:
        return TodayWorkoutPlanResponse(
            has_routines=False,
            is_rollover=False,
            active_workout=_to_workout_session_response(in_progress_workout)
            if in_progress_workout
            else None,
        )

    routines_by_day = {int(r.day_of_week): r for r in routines}

    # 3. Evaluar si ayer (o el último día programado previo) quedó sin completar -> Rollover
    week_start = datetime.now(timezone.utc) - timedelta(days=6)
    recent_completed = (
        await db.execute(
            select(Workout).where(
                Workout.user_id == current_user.id,
                Workout.status == WorkoutStatus.COMPLETED,
                Workout.date >= week_start,
            )
        )
    ).scalars().all()

    completed_routine_ids = {w.routine_id for w in recent_routine_workouts(recent_completed)}
    completed_dates = {w.date.date() for w in recent_completed}

    selected_routine: Optional[RoutineTemplate] = None
    is_rollover = False
    rollover_day: Optional[int] = None
    rollover_banner: Optional[str] = None

    # Caso prioritario: Ayer había rutina o no se entrenó ayer y existe rutina previa pendiente
    if yesterday not in completed_dates:
        # Buscar la rutina de ayer o la última rutina programada antes de hoy no completada
        candidate_prev_days = [
            d for d in sorted(routines_by_day.keys(), reverse=True) if d < today_iso_day
        ]
        if yesterday_iso_day in routines_by_day and (
            routines_by_day[yesterday_iso_day].id not in completed_routine_ids
        ):
            selected_routine = routines_by_day[yesterday_iso_day]
            is_rollover = True
            rollover_day = yesterday_iso_day
        elif candidate_prev_days:
            for prev_d in candidate_prev_days:
                cand = routines_by_day[prev_d]
                if cand.id not in completed_routine_ids:
                    selected_routine = cand
                    is_rollover = True
                    rollover_day = prev_d
                    break

    if is_rollover and selected_routine is not None:
        rollover_banner = (
            f"No se registró sesión ayer. Tu rutina pendiente "
            f"[{selected_routine.name}] pasa para hoy."
        )
    else:
        # Seleccionar la rutina del día actual o la siguiente en la rotación semanal
        if today_iso_day in routines_by_day:
            selected_routine = routines_by_day[today_iso_day]
        else:
            next_days = [d for d in sorted(routines_by_day.keys()) if d >= today_iso_day]
            selected_routine = (
                routines_by_day[next_days[0]]
                if next_days
                else routines[0]
            )

    routine_resp = await _build_routine_response(db, selected_routine, current_user.id)

    return TodayWorkoutPlanResponse(
        has_routines=True,
        is_rollover=is_rollover,
        rollover_from_day=rollover_day,
        coach_rollover_banner=rollover_banner,
        active_routine=routine_resp,
        active_workout=_to_workout_session_response(in_progress_workout)
        if in_progress_workout
        else None,
    )


def recent_routine_workouts(workouts_list: list[Workout]) -> list[Workout]:
    return [w for w in workouts_list if w.routine_id is not None]


@router.post(
    "/start-from-routine/{routine_id}",
    response_model=WorkoutSessionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def start_workout_from_routine(
    routine_id: UUID,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    is_rollover: bool = False,
) -> WorkoutSessionResponse:
    """
    Crea una sesión en vivo en `workouts` y `workout_sets` a partir de la plantilla de rutina,
    aplicando tanto la sobrecarga progresiva semanal como la autoregulación por recuperación
    del wearable del día actual.
    """
    routine = (
        await db.execute(
            select(RoutineTemplate)
            .options(
                selectinload(RoutineTemplate.items).selectinload(
                    RoutineTemplateExercise.exercise
                )
            )
            .where(
                RoutineTemplate.id == routine_id,
                RoutineTemplate.user_id == current_user.id,
            )
        )
    ).scalar_one_or_none()
    if routine is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Plantilla de rutina no encontrada.",
        )

    routine_plan = await _build_routine_response(db, routine, current_user.id)

    today_wearable = (
        await db.execute(
            select(WearableMetric)
            .where(
                WearableMetric.user_id == current_user.id,
                WearableMetric.date == date.today(),
            )
            .order_by(WearableMetric.synced_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()

    recovery_pct = (
        float(today_wearable.recovery_score) if today_wearable is not None else None
    )
    overload_step = 2.5 if current_user.unit_system.value == "KG" else 2.27

    if recovery_pct is not None and recovery_pct < 40.0:
        notes = (
            f"Recuperación {today_wearable.source_device.value} en Zona Roja ({recovery_pct:.0f}%). "
            "Gemini aplicó descarga protectora (-15% de peso)."
        )
    elif recovery_pct is not None and recovery_pct > 80.0:
        notes = (
            f"Recuperación {today_wearable.source_device.value} en Zona Verde ({recovery_pct:.0f}%). "
            f"Sobrecarga progresiva (+{overload_step:.1f} kg) activa."
        )
    else:
        notes = (
            f"Rutina activa: {routine.name}. "
            + (
                f"Arrastrada por asistencia pendiente."
                if is_rollover
                else "Pesos calculados según tu última semana."
            )
        )

    workout = Workout(
        user_id=current_user.id,
        routine_id=routine.id,
        scheduled_for_date=date.today(),
        is_rollover=is_rollover,
        status=WorkoutStatus.IN_PROGRESS,
        readiness_recovery_pct=recovery_pct,
        ai_prescription_notes=notes,
        started_at=datetime.now(timezone.utc),
    )
    db.add(workout)
    await db.flush()

    for ex_item in routine_plan.exercises:
        working_w = ex_item.recommended_weight_kg
        working_rpe = ex_item.target_rpe

        if recovery_pct is not None and recovery_pct < 40.0:
            working_w = round_to_plate_increment(working_w * 0.85)
            working_rpe = min(7.0, working_rpe)
        elif (
            recovery_pct is not None
            and recovery_pct > 80.0
            and not ex_item.progressive_overload_applied
        ):
            working_w = round_to_plate_increment(working_w + overload_step)

        for s_num in range(1, ex_item.target_sets + 1):
            db.add(
                WorkoutSet(
                    workout_id=workout.id,
                    exercise_id=ex_item.exercise_id,
                    set_number=s_num,
                    prescribed_weight=working_w,
                    prescribed_reps=ex_item.target_reps,
                    prescribed_rpe=working_rpe,
                    completed=False,
                )
            )

    await db.commit()

    full_workout = (
        await db.execute(
            select(Workout)
            .options(selectinload(Workout.sets).selectinload(WorkoutSet.exercise))
            .where(Workout.id == workout.id)
        )
    ).scalar_one()
    return _to_workout_session_response(full_workout)


@router.post(
    "",
    response_model=WorkoutSessionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def start_workout(
    payload: WorkoutStartRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> WorkoutSessionResponse:
    today_wearable = (
        await db.execute(
            select(WearableMetric)
            .where(
                WearableMetric.user_id == current_user.id,
                WearableMetric.date == date.today(),
            )
            .order_by(WearableMetric.synced_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()

    recovery_pct = float(today_wearable.recovery_score) if today_wearable else None
    overload_step = 2.5 if current_user.unit_system.value == "KG" else 2.27

    if recovery_pct is not None and recovery_pct < 40.0:
        notes = f"Readiness en Zona Roja ({recovery_pct:.0f}%). Descarga (-15% de carga) activada."
    elif recovery_pct is not None and recovery_pct > 80.0:
        notes = f"Readiness en Zona Verde ({recovery_pct:.0f}%). Sobrecarga (+{overload_step:.1f} kg) activada."
    else:
        notes = "Sesión iniciada con cargas base configuradas."

    workout = Workout(
        user_id=current_user.id,
        routine_id=payload.routine_id,
        scheduled_for_date=payload.scheduled_for_date or date.today(),
        is_rollover=payload.is_rollover,
        status=WorkoutStatus.IN_PROGRESS,
        readiness_recovery_pct=recovery_pct,
        ai_prescription_notes=notes,
        started_at=datetime.now(timezone.utc),
    )
    db.add(workout)
    await db.flush()

    for item in payload.exercises:
        ex_exists = (
            await db.execute(select(Exercise).where(Exercise.id == item.exercise_id))
        ).scalar_one_or_none()
        if ex_exists is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"El ejercicio {item.exercise_id} no existe en el catálogo.",
            )

        if recovery_pct is not None and recovery_pct < 40.0:
            adj_weight = round_to_plate_increment(item.base_weight_kg * 0.85)
            adj_rpe = min(7.0, item.target_rpe)
        elif recovery_pct is not None and recovery_pct > 80.0:
            adj_weight = round_to_plate_increment(item.base_weight_kg + overload_step)
            adj_rpe = item.target_rpe
        else:
            adj_weight = round_to_plate_increment(item.base_weight_kg)
            adj_rpe = item.target_rpe

        for s_num in range(1, item.sets_count + 1):
            db.add(
                WorkoutSet(
                    workout_id=workout.id,
                    exercise_id=item.exercise_id,
                    set_number=s_num,
                    prescribed_weight=adj_weight,
                    prescribed_reps=item.target_reps,
                    prescribed_rpe=adj_rpe,
                    completed=False,
                )
            )

    await db.commit()

    full_workout = (
        await db.execute(
            select(Workout)
            .options(selectinload(Workout.sets).selectinload(WorkoutSet.exercise))
            .where(Workout.id == workout.id, Workout.user_id == current_user.id)
        )
    ).scalar_one()
    return _to_workout_session_response(full_workout)


@router.post(
    "/{workout_id}/sets",
    response_model=SetExecutionFeedbackResponse,
    status_code=status.HTTP_200_OK,
)
async def register_set_and_adapt(
    workout_id: UUID,
    payload: SetExecutionFeedbackRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> SetExecutionFeedbackResponse:
    """
    Registra una serie ejecutada en PostgreSQL, recalcula las series restantes con Gemini,
    actualiza los pesos base de la plantilla semanal si hubo sobrecarga exitosa,
    y acredita el ELO en `ranked_points` al completar la sesión.
    """
    settings = get_settings()

    workout = (
        await db.execute(
            select(Workout).where(
                Workout.id == workout_id,
                Workout.user_id == current_user.id,
            )
        )
    ).scalar_one_or_none()
    if workout is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sesión de entrenamiento no encontrada para el usuario autenticado.",
        )

    target_set = (
        await db.execute(
            select(WorkoutSet)
            .options(selectinload(WorkoutSet.exercise))
            .where(
                WorkoutSet.workout_id == workout_id,
                WorkoutSet.exercise_id == payload.exercise_id,
                WorkoutSet.set_number == payload.set_number,
            )
        )
    ).scalar_one_or_none()
    if target_set is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Serie no encontrada en esta sesión de entrenamiento.",
        )

    exercise = target_set.exercise
    e1rm = estimate_1rm(
        weight_kg=payload.actual_weight_kg,
        reps=payload.actual_reps,
        rpe=payload.actual_rpe,
        formula=exercise.formula_1rm_type,
    )

    prescribed_w_before = float(target_set.prescribed_weight)
    prescribed_r_before = int(target_set.prescribed_reps)
    prescribed_rpe_before = float(target_set.prescribed_rpe)

    target_set.actual_weight = payload.actual_weight_kg
    target_set.reps = payload.actual_reps
    target_set.rpe = payload.actual_rpe
    target_set.estimated_1rm_kg = e1rm
    target_set.completed = True
    target_set.completed_at = datetime.now(timezone.utc)
    await db.flush()

    latest_bio = (
        await db.execute(
            select(Biometric)
            .where(Biometric.user_id == current_user.id)
            .order_by(Biometric.captured_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()

    latest_wearable = (
        await db.execute(
            select(WearableMetric)
            .where(WearableMetric.user_id == current_user.id)
            .order_by(WearableMetric.date.desc())
            .limit(1)
        )
    ).scalar_one_or_none()

    max_1rm_row = (
        await db.execute(
            select(func.max(WorkoutSet.estimated_1rm_kg))
            .join(Workout, Workout.id == WorkoutSet.workout_id)
            .where(
                Workout.user_id == current_user.id,
                WorkoutSet.exercise_id == payload.exercise_id,
            )
        )
    ).scalar_one_or_none()
    historical_1rm = float(max_1rm_row) if max_1rm_row else e1rm

    remaining_sets_rows = (
        await db.execute(
            select(WorkoutSet.set_number)
            .where(
                WorkoutSet.workout_id == workout_id,
                WorkoutSet.exercise_id == payload.exercise_id,
                WorkoutSet.set_number > payload.set_number,
                WorkoutSet.completed.is_(False),
            )
            .order_by(WorkoutSet.set_number.asc())
        )
    ).scalars().all()

    weight_kg = float(latest_bio.weight_kg) if latest_bio else 75.0
    fat_pct = float(latest_bio.fat_percentage) if latest_bio else 15.0
    muscle_kg = float(latest_bio.muscle_mass_kg) if latest_bio else 60.0
    skeletal_pct = float(latest_bio.skeletal_muscle_pct) if latest_bio else 46.0
    visceral = int(latest_bio.visceral_fat) if latest_bio else 5
    bmr_val = int(latest_bio.bmr) if latest_bio else 1800

    recovery_score = float(latest_wearable.recovery_score) if latest_wearable else 75.0
    strain_score = float(latest_wearable.strain_score) if latest_wearable else 10.0
    hrv_ms = (
        float(latest_wearable.hrv_ms)
        if (latest_wearable and latest_wearable.hrv_ms)
        else 65.0
    )
    resting_hr = (
        int(latest_wearable.resting_hr)
        if (latest_wearable and latest_wearable.resting_hr)
        else 58
    )
    sleep_hours = float(latest_wearable.sleep_hours) if latest_wearable else 7.5
    source_dev = (
        latest_wearable.source_device.value
        if latest_wearable
        else current_user.preferred_wearable.value
    )

    gemini_input: dict[str, Any] = {
        "athlete_context": {
            "user_id": str(current_user.id),
            "unit_system": current_user.unit_system.value,
            "biometrics": {
                "weight_kg": weight_kg,
                "fat_percentage": fat_pct,
                "muscle_mass_kg": muscle_kg,
                "skeletal_muscle_pct": skeletal_pct,
                "visceral_fat": visceral,
                "bmr": bmr_val,
            },
            "wearable_recovery": {
                "source_device": source_dev,
                "recovery_score": recovery_score,
                "strain_score": strain_score,
                "hrv_ms": hrv_ms,
                "resting_hr": resting_hr,
                "sleep_hours": sleep_hours,
            },
        },
        "exercise_context": {
            "exercise_id": str(exercise.id),
            "name": exercise.name,
            "category": exercise.category.value,
            "formula_1rm_type": exercise.formula_1rm_type.value,
            "historical_1rm_kg": historical_1rm,
        },
        "last_completed_set_feedback": {
            "set_number": payload.set_number,
            "completed_binary_ui": payload.completed_binary_ui,
            "prescribed_weight_kg": prescribed_w_before,
            "prescribed_reps": prescribed_r_before,
            "prescribed_rpe": prescribed_rpe_before,
            "actual_weight_kg": payload.actual_weight_kg,
            "actual_reps": payload.actual_reps,
            "actual_rpe": payload.actual_rpe,
        },
        "remaining_sets_to_recalculate": list(remaining_sets_rows),
    }

    prescription = await generate_adaptive_prescription(gemini_input)

    for upd in prescription.updated_sets:
        await db.execute(
            update(WorkoutSet)
            .where(
                WorkoutSet.workout_id == workout_id,
                WorkoutSet.exercise_id == payload.exercise_id,
                WorkoutSet.set_number == upd.set_number,
                WorkoutSet.completed.is_(False),
            )
            .values(
                prescribed_weight=upd.prescribed_weight_kg,
                prescribed_reps=upd.prescribed_reps,
                prescribed_rpe=upd.prescribed_rpe,
                ai_recalculated=True,
            )
        )

    # Si esta serie pertenecía a una rutina semanal y superó o cumplió el peso base, actualizar plantilla
    if (
        workout.routine_id is not None
        and payload.completed_binary_ui
        and payload.actual_weight_kg > 0
    ):
        await db.execute(
            update(RoutineTemplateExercise)
            .where(
                RoutineTemplateExercise.routine_id == workout.routine_id,
                RoutineTemplateExercise.exercise_id == payload.exercise_id,
                RoutineTemplateExercise.base_weight_kg < payload.actual_weight_kg,
            )
            .values(base_weight_kg=payload.actual_weight_kg)
        )

    ranked_row = (
        await db.execute(
            select(RankedPoint).where(
                RankedPoint.user_id == current_user.id,
                RankedPoint.season_id == settings.DEFAULT_SEASON_ID,
            )
        )
    ).scalar_one_or_none()
    if ranked_row is None:
        ranked_row = RankedPoint(
            user_id=current_user.id,
            season_id=settings.DEFAULT_SEASON_ID,
            current_elo=1200,
            peak_elo=1200,
            tier=RankedTier.PLATA,
        )
        db.add(ranked_row)
        await db.flush()

    all_workout_sets = (
        await db.execute(
            select(WorkoutSet)
            .options(selectinload(WorkoutSet.exercise))
            .where(WorkoutSet.workout_id == workout_id)
        )
    ).scalars().all()

    completed_sets_domain = [
        SetExecution(
            prescribed_weight_kg=float(s.prescribed_weight),
            prescribed_reps=int(s.prescribed_reps),
            prescribed_rpe=float(s.prescribed_rpe),
            actual_weight_kg=float(s.actual_weight or 0.0),
            actual_reps=int(s.reps or 0),
            actual_rpe=float(s.rpe or s.prescribed_rpe),
            completed=bool(s.completed),
            formula_1rm=s.exercise.formula_1rm_type,
        )
        for s in all_workout_sets
        if s.completed
    ]

    athlete_bio = AthleteBiometrics(
        weight_kg=weight_kg,
        fat_percentage=fat_pct,
        skeletal_muscle_pct=skeletal_pct,
        sex=current_user.biological_sex,
        recovery_score=recovery_score,
        strain_score=strain_score,
    )
    breakdown = calculate_session_metrics_and_elo(
        sets=completed_sets_domain,
        bio=athlete_bio,
        current_elo=int(ranked_row.current_elo),
    )

    workout.total_volume_kg = breakdown.raw_volume_kg
    workout.dots_normalized_volume = breakdown.dots_normalized_volume
    workout.lbm_allometric_score = breakdown.lbm_allometric_score
    workout.compliance_pct = breakdown.compliance_pct
    workout.elo_delta = breakdown.elo_delta

    any_pending = any(not s.completed for s in all_workout_sets)
    workout_finished = False
    if not any_pending and workout.status != WorkoutStatus.COMPLETED:
        workout.status = WorkoutStatus.COMPLETED
        workout.completed_at = datetime.now(timezone.utc)
        workout_finished = True
        ranked_row.current_elo = max(
            100, int(ranked_row.current_elo) + breakdown.elo_delta
        )
        ranked_row.consistency_multiplier = breakdown.biometric_consistency_multiplier
        if breakdown.elo_delta > 0:
            ranked_row.active_streak = int(ranked_row.active_streak) + 1

    await db.commit()
    await db.refresh(ranked_row)

    return SetExecutionFeedbackResponse(
        workout_id=workout_id,
        exercise_id=payload.exercise_id,
        set_number=payload.set_number,
        estimated_1rm_kg=e1rm,
        session_raw_volume_kg=breakdown.raw_volume_kg,
        session_dots_volume=breakdown.dots_normalized_volume,
        session_lbm_allometric_score=breakdown.lbm_allometric_score,
        compliance_pct=breakdown.compliance_pct,
        projected_elo_delta=breakdown.elo_delta,
        current_elo=int(ranked_row.current_elo),
        current_tier=resolve_tier(int(ranked_row.current_elo)).value,
        workout_completed=workout_finished,
        gemini_prescription=prescription,
    )
