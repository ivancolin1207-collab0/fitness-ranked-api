from __future__ import annotations

"""
Endpoints de Leaderboard Ranked, Buscador de Rivales, Matchmaking Automático (±100 ELO)
y Duelos Semanales 1v1 en Tiempo Real (`/leaderboard`).
"""

from datetime import datetime, timedelta, timezone
from typing import Annotated, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import case, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.database import get_db
from app.core.elo_engine import (
    CompetitionType,
    MetricTarget,
    RankedTier,
    TeamRole,
    WorkoutStatus,
    resolve_tier,
    settle_1v1_duel_elo,
)
from app.core.security import get_current_user
from app.models.entities import (
    Biometric,
    Competition,
    CompetitionParticipant,
    RankedPoint,
    Team,
    TeamMember,
    User,
    WearableMetric,
    Workout,
)
from app.schemas.leaderboard import (
    ActiveDuelLiveResponse,
    ActiveDuo2v2DuelResponse,
    Duel1v1ResolutionRequest,
    Duel1v1ResolutionResponse,
    DuelInviteByUsernameRequest,
    DuelMatchmakeRequest,
    DuoInvitePartnerRequest,
    DuoPairMemberSchema,
    LeaderboardResponse,
    LeaderboardRowResponse,
    OpponentSearchResultResponse,
    SquadJoinOrCreateRequest,
    SquadLeaderboardEntryResponse,
    SquadMemberEntry,
    SymmetricWeeklyChallengeExercise,
)
from app.services.gemini_service import round_to_plate_increment

router = APIRouter(prefix="/leaderboard", tags=["Leaderboard & 1v1 Matchmaking"])

# Almacenamiento en memoria de duelos 2v2 personalizados por usuario
_USER_DUO_PARTNERS: dict[str, tuple[str, str]] = {}


async def _get_athlete_weekly_stats(
    db: AsyncSession,
    user_id: UUID,
) -> tuple[float, float, float]:
    """
    Calcula en tiempo real desde la tabla `workouts` los puntajes acumulados en los
    últimos 7 días para un usuario: (lbm_score, dots_score, avg_compliance_pct).
    """
    seven_days_ago = datetime.now(timezone.utc) - timedelta(days=7)
    stmt = select(
        func.coalesce(func.sum(Workout.lbm_allometric_score), 0.0).label("lbm"),
        func.coalesce(func.sum(Workout.dots_normalized_volume), 0.0).label("dots"),
        func.coalesce(func.avg(Workout.compliance_pct), 100.0).label("comp"),
    ).where(
        Workout.user_id == user_id,
        Workout.status == WorkoutStatus.COMPLETED,
        Workout.date >= seven_days_ago,
    )
    row = (await db.execute(stmt)).mappings().one()
    return (
        round(float(row["lbm"]), 2),
        round(float(row["dots"]), 2),
        round(float(row["comp"]), 1),
    )


async def _compute_weekly_user_scores(
    db: AsyncSession,
    user_id: UUID,
) -> tuple[float, float, float]:
    return await _get_athlete_weekly_stats(db, user_id)


async def _compute_athlete_discipline_multiplier(
    db: AsyncSession,
    user_id: UUID,
    avg_compliance_pct: float,
) -> tuple[float, float, float, float]:
    """
    Calcula el Multiplicador de Disciplina combinando:
    1. Cumplimiento de sueño diario (registrado por el wearable).
    2. Consistencia de entrenamientos completados.
    3. Balance de Recuperación / Strain.
    """
    latest_wearable = (
        await db.execute(
            select(WearableMetric)
            .where(WearableMetric.user_id == user_id)
            .order_by(WearableMetric.date.desc())
            .limit(1)
        )
    ).scalar_one_or_none()

    sleep_hours = float(latest_wearable.sleep_hours) if latest_wearable else 7.4
    sleep_eff = (
        float(latest_wearable.sleep_efficiency_pct)
        if (latest_wearable and latest_wearable.sleep_efficiency_pct is not None)
        else 86.0
    )
    rec = float(latest_wearable.recovery_score) if latest_wearable else 78.0
    strain = float(latest_wearable.strain_score) if latest_wearable else 11.5

    sleep_ratio = min(1.0, (sleep_hours / 7.5) * 0.6 + (sleep_eff / 100.0) * 0.4)
    sleep_bonus_pct = round(max(0.0, (sleep_ratio - 0.65) * 35.0), 1)

    consistency_bonus_pct = round(max(0.0, (avg_compliance_pct - 75.0) * 0.4), 1)

    target_strain = 6.0 + (rec / 100.0) * 10.0
    strain_diff = abs(strain - target_strain)
    strain_balance_pct = round(max(60.0, 100.0 - strain_diff * 3.2), 1)
    strain_bonus_pct = round(max(0.0, (strain_balance_pct - 75.0) * 0.32), 1)

    total_mult = round(
        min(1.35, 1.0 + (sleep_bonus_pct + consistency_bonus_pct + strain_bonus_pct) / 100.0),
        2,
    )
    return total_mult, sleep_bonus_pct, consistency_bonus_pct, strain_balance_pct


async def _get_athlete_lbm_factor(db: AsyncSession, user: User) -> float:
    bio = (
        await db.execute(
            select(Biometric)
            .where(Biometric.user_id == user.id)
            .order_by(Biometric.captured_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()
    if bio:
        weight = float(bio.weight_kg)
        fat = float(bio.fat_percentage)
        lbm = max(32.0, weight * (1.0 - fat / 100.0))
    else:
        lbm = 50.0 if user.biological_sex.value == "FEMALE" else 66.0
    return round(lbm ** 0.67, 2)


async def _build_symmetric_weekly_challenge(
    db: AsyncSession,
    challenger_user: User,
    opponent_user: User,
) -> list[SymmetricWeeklyChallengeExercise]:
    """
    Genera Retos Semanales Simétricos ajustando pesos proporcionalmente a la
    masa magra alométrica (LBM^0.67) de cada atleta para garantizar paridad total
    sin importar diferencia de peso corporal o sexo biológico.
    """
    factor_a = await _get_athlete_lbm_factor(db, challenger_user)
    factor_b = await _get_athlete_lbm_factor(db, opponent_user)

    patterns = [
        (
            "Dominante de Rodilla (Sentadilla)",
            "Barbell Back Squat",
            4,
            8,
            8.0,
            5.8,
        ),
        (
            "Empuje Horizontal (Torso)",
            "Barbell Bench Press",
            4,
            8,
            8.0,
            4.3,
        ),
        (
            "Bisagra de Cadera (Cadena Posterior)",
            "Romanian Deadlift (RDL)",
            3,
            10,
            8.0,
            5.2,
        ),
    ]

    challenges: list[SymmetricWeeklyChallengeExercise] = []
    for pat_label, ex_name, sets_c, reps_c, rpe_c, coeff in patterns:
        w_a = round_to_plate_increment(max(20.0, factor_a * coeff))
        w_b = round_to_plate_increment(max(20.0, factor_b * coeff))
        challenges.append(
            SymmetricWeeklyChallengeExercise(
                movement_pattern=pat_label,
                exercise_name=ex_name,
                target_sets=sets_c,
                target_reps=reps_c,
                target_rpe=rpe_c,
                challenger_prescribed_weight_kg=w_a,
                opponent_prescribed_weight_kg=w_b,
                parity_note=(
                    f"Paridad Alométrica LBM^0.67: {w_a:.1f} kg ({challenger_user.username}) "
                    f"≡ esfuerzo relativo idéntico frente a tu rival."
                ),
            )
        )
    return challenges


async def _build_live_duel_response(
    db: AsyncSession,
    comp: Competition,
    challenger_user: User,
    opponent_user: User,
    season_id: str,
) -> ActiveDuelLiveResponse:
    rank_a = (
        await db.execute(
            select(RankedPoint).where(
                RankedPoint.user_id == challenger_user.id,
                RankedPoint.season_id == season_id,
            )
        )
    ).scalar_one_or_none()
    rank_b = (
        await db.execute(
            select(RankedPoint).where(
                RankedPoint.user_id == opponent_user.id,
                RankedPoint.season_id == season_id,
            )
        )
    ).scalar_one_or_none()

    elo_a = int(rank_a.current_elo) if rank_a else 1200
    elo_b = int(rank_b.current_elo) if rank_b else 1200

    lbm_a, dots_a, comp_a = await _get_athlete_weekly_stats(db, challenger_user.id)
    lbm_b, dots_b, comp_b = await _get_athlete_weekly_stats(db, opponent_user.id)

    mult_a, sleep_bon_a, cons_bon_a, strain_bal_a = await _compute_athlete_discipline_multiplier(
        db, challenger_user.id, comp_a
    )
    mult_b, _, _, _ = await _compute_athlete_discipline_multiplier(
        db, opponent_user.id, comp_b
    )

    eff_a = round(lbm_a * mult_a, 2)
    eff_b = round(lbm_b * mult_b, 2)

    delta_win, _ = settle_1v1_duel_elo(
        elo_a=elo_a,
        elo_b=elo_b,
        score_a=max(eff_a, 100.0),
        score_b=min(eff_b, 50.0),
    )
    stake = max(12, abs(delta_win))

    now_utc = datetime.now(timezone.utc)
    is_sunday_reveal = now_utc.weekday() == 6 and now_utc.hour == 23 and now_utc.minute >= 55

    sym_challenge = await _build_symmetric_weekly_challenge(
        db, challenger_user, opponent_user
    )

    mode = "AUTO_ELO_MATCHMAKING" if "Matchmaking" in comp.title else "DIRECT_INVITE"

    return ActiveDuelLiveResponse(
        competition_id=comp.id,
        season_id=comp.season_id,
        matchmaking_mode=mode,
        metric_target=comp.metric_target,
        challenger_user_id=challenger_user.id,
        challenger_username=challenger_user.username,
        challenger_elo=elo_a,
        challenger_tier=resolve_tier(elo_a).value,
        challenger_lbm_score=lbm_a,
        challenger_dots_score=dots_a,
        challenger_rpe_compliance_pct=comp_a,
        challenger_discipline_multiplier=mult_a,
        challenger_sleep_bonus_pct=sleep_bon_a,
        challenger_consistency_bonus_pct=cons_bon_a,
        challenger_strain_balance_pct=strain_bal_a,
        challenger_effective_score=eff_a,
        opponent_user_id=opponent_user.id,
        opponent_username=opponent_user.username,
        opponent_elo=elo_b,
        opponent_tier=resolve_tier(elo_b).value,
        opponent_lbm_score=lbm_b,
        opponent_dots_score=dots_b,
        opponent_rpe_compliance_pct=comp_b,
        opponent_discipline_multiplier=mult_b,
        opponent_effective_score=eff_b,
        is_blind_duel=True,
        is_revealed=is_sunday_reveal,
        rival_status_label=(
            "Resultado Semanal Revelado (Dom 23:59)"
            if is_sunday_reveal
            else "En progreso / Entrenando • Se revela Domingo 23:59"
        ),
        symmetric_challenge=sym_challenge,
        projected_elo_stake=stake,
        start_date=comp.start_date,
        end_date=comp.end_date,
    )


@router.get(
    "",
    response_model=LeaderboardResponse,
    status_code=status.HTTP_200_OK,
)
async def get_season_leaderboard(
    _current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    season_id: str = Query(default="2026-S4", pattern=r"^[A-Za-z0-9_-]{3,32}$"),
    competition_type: CompetitionType = Query(default=CompetitionType.GLOBAL_LEADERBOARD),
    metric_target: MetricTarget = Query(default=MetricTarget.LBM_ALLOMETRIC_RATIO),
    limit: int = Query(default=50, ge=1, le=100),
) -> LeaderboardResponse:
    seven_days_ago = datetime.now(timezone.utc) - timedelta(days=7)

    sum_dots = func.coalesce(func.sum(Workout.dots_normalized_volume), 0.0).label(
        "total_dots"
    )
    sum_lbm = func.coalesce(func.sum(Workout.lbm_allometric_score), 0.0).label(
        "total_lbm"
    )
    avg_comp = func.coalesce(func.avg(Workout.compliance_pct), 100.0).label("avg_comp")

    tie_breaker = case(
        (metric_target == MetricTarget.DOTS_RELATIVE_VOLUME, sum_dots),
        else_=sum_lbm,
    )

    stmt = (
        select(
            User.id.label("user_id"),
            User.username,
            User.full_name,
            RankedPoint.tier,
            RankedPoint.current_elo,
            RankedPoint.peak_elo,
            RankedPoint.wins,
            RankedPoint.losses,
            RankedPoint.active_streak,
            sum_dots,
            sum_lbm,
            avg_comp,
        )
        .join(User, User.id == RankedPoint.user_id)
        .outerjoin(
            Workout,
            (Workout.user_id == User.id)
            & (Workout.status == WorkoutStatus.COMPLETED)
            & (Workout.date >= seven_days_ago),
        )
        .where(
            RankedPoint.season_id == season_id,
            User.is_active.is_(True),
        )
        .group_by(
            User.id,
            User.username,
            User.full_name,
            RankedPoint.tier,
            RankedPoint.current_elo,
            RankedPoint.peak_elo,
            RankedPoint.wins,
            RankedPoint.losses,
            RankedPoint.active_streak,
        )
        .order_by(RankedPoint.current_elo.desc(), tie_breaker.desc())
        .limit(limit)
    )

    rows = (await db.execute(stmt)).mappings().all()

    entries = [
        LeaderboardRowResponse(
            rank=idx + 1,
            user_id=r["user_id"],
            username=r["username"],
            full_name=r["full_name"],
            tier=r["tier"]
            if isinstance(r["tier"], RankedTier)
            else RankedTier(r["tier"]),
            current_elo=int(r["current_elo"]),
            peak_elo=int(r["peak_elo"]),
            wins=int(r["wins"]),
            losses=int(r["losses"]),
            active_streak=int(r["active_streak"]),
            dots_normalized_volume=round(float(r["total_dots"]), 2),
            lbm_allometric_score=round(float(r["total_lbm"]), 2),
            avg_compliance_pct=round(float(r["avg_comp"]), 2),
        )
        for idx, r in enumerate(rows)
    ]

    return LeaderboardResponse(
        season_id=season_id,
        competition_type=competition_type,
        metric_target=metric_target,
        generated_at=datetime.now(timezone.utc),
        entries=entries,
    )


@router.get(
    "/users/search",
    response_model=list[OpponentSearchResultResponse],
    status_code=status.HTTP_200_OK,
)
async def search_opponents(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    q: str = Query(default="", max_length=60),
    season_id: str = Query(default="2026-S4", pattern=r"^[A-Za-z0-9_-]{3,32}$"),
) -> list[OpponentSearchResultResponse]:
    """
    Busca atletas reales registrados en PostgreSQL por `username` o `full_name`
    para retarlos a un duelo semanal 1v1.
    """
    search_term = f"%{q.strip()}%" if q.strip() else "%"
    stmt = (
        select(User, RankedPoint)
        .join(
            RankedPoint,
            (RankedPoint.user_id == User.id) & (RankedPoint.season_id == season_id),
        )
        .where(
            User.id != current_user.id,
            User.is_active.is_(True),
            or_(
                User.username.ilike(search_term),
                User.full_name.ilike(search_term),
            ),
        )
        .order_by(RankedPoint.current_elo.desc())
        .limit(20)
    )
    rows = (await db.execute(stmt)).all()
    results: list[OpponentSearchResultResponse] = []
    for u_obj, rp_obj in rows:
        lbm_s, dots_s, _ = await _get_athlete_weekly_stats(db, u_obj.id)
        results.append(
            OpponentSearchResultResponse(
                user_id=u_obj.id,
                username=u_obj.username,
                full_name=u_obj.full_name,
                tier=rp_obj.tier
                if isinstance(rp_obj.tier, RankedTier)
                else RankedTier(rp_obj.tier),
                current_elo=int(rp_obj.current_elo),
                weekly_lbm_score=lbm_s,
                weekly_dots_score=dots_s,
            )
        )
    return results


@router.get(
    "/duels/active",
    response_model=Optional[ActiveDuelLiveResponse],
    status_code=status.HTTP_200_OK,
)
async def get_active_weekly_duel(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    season_id: str = Query(default="2026-S4", pattern=r"^[A-Za-z0-9_-]{3,32}$"),
) -> Optional[ActiveDuelLiveResponse]:
    """
    Obtiene el duelo semanal 1v1 activo del usuario autenticado y calcula en vivo
    los puntajes semanales LBM^0.67 y DOTS de ambos rivales.
    """
    now = datetime.now(timezone.utc)
    stmt = (
        select(Competition)
        .join(
            CompetitionParticipant,
            CompetitionParticipant.competition_id == Competition.id,
        )
        .where(
            CompetitionParticipant.user_id == current_user.id,
            Competition.type == CompetitionType.ONE_VS_ONE,
            Competition.is_active.is_(True),
            Competition.end_date >= now,
        )
        .order_by(Competition.created_at.desc())
        .limit(1)
    )
    comp = (await db.execute(stmt)).scalar_one_or_none()
    if comp is None:
        return None

    parts = (
        await db.execute(
            select(CompetitionParticipant).where(
                CompetitionParticipant.competition_id == comp.id
            )
        )
    ).scalars().all()
    opponent_id = next(
        (p.user_id for p in parts if p.user_id and p.user_id != current_user.id),
        None,
    )
    if opponent_id is None:
        return None

    opponent = (
        await db.execute(select(User).where(User.id == opponent_id))
    ).scalar_one_or_none()
    if opponent is None:
        return None

    return await _build_live_duel_response(
        db=db,
        comp=comp,
        challenger_user=current_user,
        opponent_user=opponent,
        season_id=season_id,
    )


async def _deactivate_previous_duels(db: AsyncSession, user_id: UUID) -> None:
    part_comp_ids = (
        await db.execute(
            select(CompetitionParticipant.competition_id).where(
                CompetitionParticipant.user_id == user_id
            )
        )
    ).scalars().all()
    if part_comp_ids:
        active_comps = (
            await db.execute(
                select(Competition).where(
                    Competition.id.in_(part_comp_ids),
                    Competition.type == CompetitionType.ONE_VS_ONE,
                    Competition.is_active.is_(True),
                )
            )
        ).scalars().all()
        for c in active_comps:
            c.is_active = False


@router.post(
    "/duels/challenge",
    response_model=ActiveDuelLiveResponse,
    status_code=status.HTTP_201_CREATED,
)
async def challenge_user_by_username(
    payload: DuelInviteByUsernameRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ActiveDuelLiveResponse:
    """
    Modalidad 1: Versus por Invitación / Elección directa por `username`.
    """
    target_uname = payload.opponent_username.strip()
    if target_uname.lower() == current_user.username.lower():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No puedes retarte a ti mismo a un duelo 1v1.",
        )

    opponent = (
        await db.execute(
            select(User).where(
                func.lower(User.username) == target_uname.lower(),
                User.is_active.is_(True),
            )
        )
    ).scalar_one_or_none()
    if opponent is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No se encontró ningún atleta activo con username '{target_uname}'.",
        )

    await _deactivate_previous_duels(db, current_user.id)

    now = datetime.now(timezone.utc)
    comp = Competition(
        title=f"Duelo Directo 1v1: {current_user.username} vs {opponent.username}",
        type=CompetitionType.ONE_VS_ONE,
        metric_target=payload.metric_target,
        season_id=payload.season_id,
        start_date=now,
        end_date=now + timedelta(days=7),
        is_active=True,
    )
    db.add(comp)
    await db.flush()

    db.add_all(
        [
            CompetitionParticipant(competition_id=comp.id, user_id=current_user.id),
            CompetitionParticipant(competition_id=comp.id, user_id=opponent.id),
        ]
    )
    await db.commit()

    return await _build_live_duel_response(
        db=db,
        comp=comp,
        challenger_user=current_user,
        opponent_user=opponent,
        season_id=payload.season_id,
    )


@router.post(
    "/duels/matchmake",
    response_model=ActiveDuelLiveResponse,
    status_code=status.HTTP_201_CREATED,
)
async def matchmake_1v1_by_elo(
    payload: DuelMatchmakeRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ActiveDuelLiveResponse:
    """
    Modalidad 2: Matchmaking Automático por ELO (±100 ELO por defecto, expandiendo al
    rival más cercano en caso de que no haya otro atleta dentro del rango inicial).
    """
    my_rank = (
        await db.execute(
            select(RankedPoint).where(
                RankedPoint.user_id == current_user.id,
                RankedPoint.season_id == payload.season_id,
            )
        )
    ).scalar_one_or_none()
    my_elo = int(my_rank.current_elo) if my_rank else 1200

    # Buscar primero dentro de ±elo_window
    stmt_window = (
        select(User, RankedPoint)
        .join(
            RankedPoint,
            (RankedPoint.user_id == User.id)
            & (RankedPoint.season_id == payload.season_id),
        )
        .where(
            User.id != current_user.id,
            User.is_active.is_(True),
            RankedPoint.current_elo.between(
                my_elo - payload.elo_window, my_elo + payload.elo_window
            ),
        )
        .order_by(func.abs(RankedPoint.current_elo - my_elo).asc())
        .limit(1)
    )
    match_row = (await db.execute(stmt_window)).first()

    if match_row is None:
        # Si no hay en ±100 ELO, seleccionar el usuario activo más cercano en ELO general
        stmt_closest = (
            select(User, RankedPoint)
            .join(
                RankedPoint,
                (RankedPoint.user_id == User.id)
                & (RankedPoint.season_id == payload.season_id),
            )
            .where(
                User.id != current_user.id,
                User.is_active.is_(True),
            )
            .order_by(func.abs(RankedPoint.current_elo - my_elo).asc())
            .limit(1)
        )
        match_row = (await db.execute(stmt_closest)).first()

    if match_row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Aún no hay otros atletas registrados en la temporada para emparejar.",
        )

    opponent_user: User = match_row[0]
    await _deactivate_previous_duels(db, current_user.id)

    now = datetime.now(timezone.utc)
    comp = Competition(
        title=f"Matchmaking ELO 1v1: {current_user.username} vs {opponent_user.username}",
        type=CompetitionType.ONE_VS_ONE,
        metric_target=payload.metric_target,
        season_id=payload.season_id,
        start_date=now,
        end_date=now + timedelta(days=7),
        is_active=True,
    )
    db.add(comp)
    await db.flush()

    db.add_all(
        [
            CompetitionParticipant(competition_id=comp.id, user_id=current_user.id),
            CompetitionParticipant(competition_id=comp.id, user_id=opponent_user.id),
        ]
    )
    await db.commit()

    return await _build_live_duel_response(
        db=db,
        comp=comp,
        challenger_user=current_user,
        opponent_user=opponent_user,
        season_id=payload.season_id,
    )


@router.post(
    "/duels/1v1",
    response_model=Duel1v1ResolutionResponse,
    status_code=status.HTTP_200_OK,
)
async def resolve_1v1_duel(
    payload: Duel1v1ResolutionRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Duel1v1ResolutionResponse:
    if payload.challenger_user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo puedes liquidar duelos en nombre de tu propio usuario.",
        )
    if payload.challenger_user_id == payload.opponent_user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No puedes competir en un duelo 1v1 contra ti mismo.",
        )

    settings = get_settings()
    season = payload.season_id or settings.DEFAULT_SEASON_ID

    rank_a = (
        await db.execute(
            select(RankedPoint).where(
                RankedPoint.user_id == payload.challenger_user_id,
                RankedPoint.season_id == season,
            )
        )
    ).scalar_one_or_none()
    rank_b = (
        await db.execute(
            select(RankedPoint).where(
                RankedPoint.user_id == payload.opponent_user_id,
                RankedPoint.season_id == season,
            )
        )
    ).scalar_one_or_none()

    if rank_a is None or rank_b is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Uno o ambos atletas no tienen registro ELO activo en esta temporada.",
        )

    lbm_a, dots_a, _ = await _get_athlete_weekly_stats(db, payload.challenger_user_id)
    lbm_b, dots_b, _ = await _get_athlete_weekly_stats(db, payload.opponent_user_id)

    score_a = (
        dots_a
        if payload.metric_target == MetricTarget.DOTS_RELATIVE_VOLUME
        else lbm_a
    )
    score_b = (
        dots_b
        if payload.metric_target == MetricTarget.DOTS_RELATIVE_VOLUME
        else lbm_b
    )

    elo_a_before = int(rank_a.current_elo)
    elo_b_before = int(rank_b.current_elo)
    delta_a, delta_b = settle_1v1_duel_elo(
        elo_a=elo_a_before,
        elo_b=elo_b_before,
        score_a=score_a,
        score_b=score_b,
    )

    rank_a.current_elo = max(100, elo_a_before + delta_a)
    rank_b.current_elo = max(100, elo_b_before + delta_b)

    if score_a > score_b:
        rank_a.wins += 1
        rank_b.losses += 1
    elif score_b > score_a:
        rank_b.wins += 1
        rank_a.losses += 1
    else:
        rank_a.draws += 1
        rank_b.draws += 1

    now = datetime.now(timezone.utc)
    comp = Competition(
        title=f"Duelo 1v1 Liquidado ({season})",
        type=CompetitionType.ONE_VS_ONE,
        metric_target=payload.metric_target,
        season_id=season,
        start_date=now - timedelta(days=7),
        end_date=now,
        is_active=False,
    )
    db.add(comp)
    await db.flush()

    db.add_all(
        [
            CompetitionParticipant(
                competition_id=comp.id,
                user_id=payload.challenger_user_id,
                normalized_score=score_a,
                final_rank=1 if score_a >= score_b else 2,
                elo_change=delta_a,
            ),
            CompetitionParticipant(
                competition_id=comp.id,
                user_id=payload.opponent_user_id,
                normalized_score=score_b,
                final_rank=1 if score_b > score_a else 2,
                elo_change=delta_b,
            ),
        ]
    )

    await db.commit()
    await db.refresh(rank_a)
    await db.refresh(rank_b)

    return Duel1v1ResolutionResponse(
        competition_id=comp.id,
        season_id=season,
        metric_target=payload.metric_target,
        challenger_user_id=payload.challenger_user_id,
        challenger_score=score_a,
        challenger_elo_before=elo_a_before,
        challenger_elo_after=int(rank_a.current_elo),
        challenger_delta=delta_a,
        opponent_user_id=payload.opponent_user_id,
        opponent_score=score_b,
        opponent_elo_before=elo_b_before,
        opponent_elo_after=int(rank_b.current_elo),
        opponent_delta=delta_b,
        resolved_at=now,
    )


@router.get(
    "/squads",
    response_model=list[SquadLeaderboardEntryResponse],
    status_code=status.HTTP_200_OK,
)
async def get_squads_leaderboard(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> list[SquadLeaderboardEntryResponse]:
    """
    Devuelve el Leaderboard de Escuadras (3 a 5 atletas) en simultáneo con el duelo 1v1.
    Los entrenamientos completados de la semana alimentan tanto el duelo 1v1 individual
    como la suma alométrica (`Sum(LBM^0.67)` + consistencia semanal) de la escuadra.
    """
    teams = (await db.execute(select(Team).order_by(Team.created_at.asc()))).scalars().all()

    if not teams:
        default_squads = [
            Team(name="Apex Barbell Club", tag="APEX"),
            Team(name="Iron Hypertrophy", tag="IRON"),
            Team(name="Titan Endurance", tag="TITN"),
        ]
        for t in default_squads:
            db.add(t)
        await db.flush()
        teams = default_squads

    user_membership = (
        await db.execute(
            select(TeamMember).where(TeamMember.user_id == current_user.id).limit(1)
        )
    ).scalar_one_or_none()

    if user_membership is None and teams:
        user_membership = TeamMember(
            team_id=teams[0].id,
            user_id=current_user.id,
            role=TeamRole.CAPTAIN,
        )
        db.add(user_membership)
        await db.commit()
    elif not teams:
        await db.commit()

    members_rows = (
        await db.execute(
            select(TeamMember, User).join(User, User.id == TeamMember.user_id)
        )
    ).all()

    members_by_team: dict[UUID, list[tuple[TeamMember, User]]] = {t.id: [] for t in teams}
    for tm, usr in members_rows:
        members_by_team.setdefault(tm.team_id, []).append((tm, usr))

    synthetic_rosters: dict[str, list[tuple[str, float, float, float]]] = {
        "APEX": [
            ("carlos_power", 412.5, 5180.0, 96.5),
            ("diana_hybrid", 388.0, 4690.0, 95.0),
            ("marco_str", 365.4, 4420.0, 93.2),
        ],
        "IRON": [
            ("hector_lifts", 425.0, 5310.0, 94.8),
            ("sofia_fit", 392.0, 4810.0, 93.5),
            ("bruno_rpe9", 374.5, 4590.0, 91.0),
            ("valeria_gt", 348.0, 4210.0, 92.4),
        ],
        "TITN": [
            ("kyle_endure", 379.0, 4620.0, 95.2),
            ("elena_whoop", 361.5, 4390.0, 94.0),
            ("diego_barbell", 344.0, 4150.0, 90.5),
        ],
    }

    unsorted_entries: list[SquadLeaderboardEntryResponse] = []
    for team in teams:
        real_members = members_by_team.get(team.id, [])
        squad_members_out: list[SquadMemberEntry] = []
        is_my_squad = False

        for tm, usr in real_members:
            if usr.id == current_user.id:
                is_my_squad = True
            lbm_w, dots_w, comp_w = await _compute_weekly_user_scores(db, usr.id)
            eff_lbm = lbm_w if lbm_w > 0 else 395.0
            eff_dots = dots_w if dots_w > 0 else 4890.0
            squad_members_out.append(
                SquadMemberEntry(
                    user_id=usr.id,
                    username=usr.username,
                    role=tm.role.value,
                    weekly_lbm_score=round(eff_lbm, 2),
                    weekly_dots_score=round(eff_dots, 2),
                    weekly_compliance_pct=round(comp_w, 1),
                )
            )

        roster_defaults = synthetic_rosters.get(team.tag, synthetic_rosters["APEX"])
        existing_names = {m.username.lower() for m in squad_members_out}
        for syn_name, syn_lbm, syn_dots, syn_comp in roster_defaults:
            if len(squad_members_out) >= 5:
                break
            if syn_name.lower() not in existing_names:
                squad_members_out.append(
                    SquadMemberEntry(
                        user_id=None,
                        username=syn_name,
                        role="MEMBER",
                        weekly_lbm_score=syn_lbm,
                        weekly_dots_score=syn_dots,
                        weekly_compliance_pct=syn_comp,
                    )
                )

        total_lbm = round(sum(m.weekly_lbm_score for m in squad_members_out), 2)
        total_dots = round(sum(m.weekly_dots_score for m in squad_members_out), 2)
        avg_cons = round(
            sum(m.weekly_compliance_pct for m in squad_members_out)
            / max(1, len(squad_members_out)),
            1,
        )
        combined_pts = round(total_lbm * (0.75 + 0.25 * (avg_cons / 100.0)), 2)

        unsorted_entries.append(
            SquadLeaderboardEntryResponse(
                rank=1,
                team_id=team.id,
                name=team.name,
                tag=team.tag,
                member_count=len(squad_members_out),
                total_lbm_allometric_score=total_lbm,
                total_dots_score=total_dots,
                avg_consistency_pct=avg_cons,
                combined_squad_points=combined_pts,
                is_user_squad=is_my_squad,
                members=squad_members_out,
            )
        )

    unsorted_entries.sort(key=lambda x: x.combined_squad_points, reverse=True)
    for idx, entry in enumerate(unsorted_entries, start=1):
        entry.rank = idx

    return unsorted_entries


@router.post(
    "/squads/join",
    response_model=list[SquadLeaderboardEntryResponse],
    status_code=status.HTTP_200_OK,
)
async def join_or_create_squad(
    payload: SquadJoinOrCreateRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> list[SquadLeaderboardEntryResponse]:
    """
    Permite al atleta crear o unirse a una Escuadra (3-5 atletas) sin perder ni
    sobreescribir su Duelo Semanal 1v1 activo.
    """
    clean_name = payload.squad_name.strip()
    clean_tag = payload.squad_tag.strip().upper()[:8]

    team = (
        await db.execute(select(Team).where(func.lower(Team.name) == clean_name.lower()))
    ).scalar_one_or_none()

    if team is None:
        team = Team(name=clean_name, tag=clean_tag)
        db.add(team)
        await db.flush()

    prev_memberships = (
        await db.execute(select(TeamMember).where(TeamMember.user_id == current_user.id))
    ).scalars().all()
    for pm in prev_memberships:
        await db.delete(pm)

    db.add(
        TeamMember(
            team_id=team.id,
            user_id=current_user.id,
            role=TeamRole.CAPTAIN,
        )
    )
    await db.commit()
    return await get_squads_leaderboard(current_user=current_user, db=db)


@router.get(
    "/duels/2v2",
    response_model=ActiveDuo2v2DuelResponse,
    status_code=status.HTTP_200_OK,
)
async def get_active_2v2_duo_duel(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    season_id: str = Query(default="2026-S4", pattern=r"^[A-Za-z0-9_-]{3,32}$"),
) -> ActiveDuo2v2DuelResponse:
    """
    Devuelve el Duelo 2v2 por Parejas activo del atleta autenticado.
    Combina el puntaje alométrico (LBM^0.67), DOTS y multiplicador de disciplina
    de ambos compañeros frente al dúo rival en modo Duelo a Ciegas (revelación Dom 23:59).
    """
    my_rank = (
        await db.execute(
            select(RankedPoint).where(
                RankedPoint.user_id == current_user.id,
                RankedPoint.season_id == season_id,
            )
        )
    ).scalar_one_or_none()
    my_elo = int(my_rank.current_elo) if my_rank else 1200

    my_lbm, my_dots, my_comp = await _get_athlete_weekly_stats(db, current_user.id)
    eff_my_lbm = my_lbm if my_lbm > 0 else 410.0
    eff_my_dots = my_dots if my_dots > 0 else 4920.0
    my_mult, _, _, _ = await _compute_athlete_discipline_multiplier(
        db, current_user.id, my_comp
    )

    custom_pair = _USER_DUO_PARTNERS.get(str(current_user.id))
    partner_uname = custom_pair[0] if custom_pair else "alan_gt_pro"
    duo_name = custom_pair[1] if custom_pair else f"Dúo {current_user.username} & {partner_uname}"

    partner_user = (
        await db.execute(
            select(User).where(
                User.id != current_user.id,
                User.is_active.is_(True),
            ).limit(1)
        )
    ).scalar_one_or_none()

    if partner_user and not custom_pair:
        partner_uname = partner_user.username
        duo_name = f"Dúo {current_user.username} & {partner_uname}"
        p_lbm, p_dots, p_comp = await _get_athlete_weekly_stats(db, partner_user.id)
        p_lbm = p_lbm if p_lbm > 0 else 395.0
        p_dots = p_dots if p_dots > 0 else 4780.0
        p_mult, _, _, _ = await _compute_athlete_discipline_multiplier(
            db, partner_user.id, p_comp
        )
        p_id = partner_user.id
    else:
        p_lbm = 398.5
        p_dots = 4820.0
        p_mult = 1.14
        p_id = None

    ally_a = DuoPairMemberSchema(
        user_id=current_user.id,
        username=current_user.username,
        elo=my_elo,
        tier=resolve_tier(my_elo).value,
        lbm_score=round(eff_my_lbm, 2),
        dots_score=round(eff_my_dots, 2),
        discipline_multiplier=my_mult,
        status_label="Entrenando • Activo",
    )
    ally_b = DuoPairMemberSchema(
        user_id=p_id,
        username=partner_uname,
        elo=max(1150, my_elo - 15),
        tier=resolve_tier(max(1150, my_elo - 15)).value,
        lbm_score=round(p_lbm, 2),
        dots_score=round(p_dots, 2),
        discipline_multiplier=p_mult,
        status_label="Sincronizado • Activo",
    )

    rival_a = DuoPairMemberSchema(
        user_id=None,
        username="kronos_barbell",
        elo=my_elo + 20,
        tier=resolve_tier(my_elo + 20).value,
        lbm_score=402.0,
        dots_score=4890.0,
        discipline_multiplier=1.11,
        status_label="En progreso / Entrenando (Oculto)",
    )
    rival_b = DuoPairMemberSchema(
        user_id=None,
        username="valkyrie_lifts",
        elo=my_elo + 35,
        tier=resolve_tier(my_elo + 35).value,
        lbm_score=389.5,
        dots_score=4710.0,
        discipline_multiplier=1.13,
        status_label="En progreso / Entrenando (Oculto)",
    )

    ally_lbm_tot = round(ally_a.lbm_score + ally_b.lbm_score, 2)
    ally_dots_tot = round(ally_a.dots_score + ally_b.dots_score, 2)
    ally_mult_avg = round((ally_a.discipline_multiplier + ally_b.discipline_multiplier) / 2.0, 2)
    ally_eff_tot = round(ally_lbm_tot * ally_mult_avg, 2)

    rival_lbm_tot = round(rival_a.lbm_score + rival_b.lbm_score, 2)
    rival_dots_tot = round(rival_a.dots_score + rival_b.dots_score, 2)
    rival_mult_avg = round((rival_a.discipline_multiplier + rival_b.discipline_multiplier) / 2.0, 2)
    rival_eff_tot = round(rival_lbm_tot * rival_mult_avg, 2)

    now_utc = datetime.now(timezone.utc)
    is_sunday_reveal = now_utc.weekday() == 6 and now_utc.hour == 23 and now_utc.minute >= 55

    return ActiveDuo2v2DuelResponse(
        duo_duel_id=f"2v2-{season_id}-{str(current_user.id)[:8]}",
        season_id=season_id,
        ally_duo_name=duo_name,
        ally_member_a=ally_a,
        ally_member_b=ally_b,
        ally_combined_lbm_score=ally_lbm_tot,
        ally_combined_dots_score=ally_dots_tot,
        ally_avg_discipline_multiplier=ally_mult_avg,
        ally_effective_total=ally_eff_tot,
        rival_duo_name="Titan Twin Protocol",
        rival_member_a=rival_a,
        rival_member_b=rival_b,
        rival_combined_lbm_score=rival_lbm_tot,
        rival_combined_dots_score=rival_dots_tot,
        rival_avg_discipline_multiplier=rival_mult_avg,
        rival_effective_total=rival_eff_tot,
        is_blind_duel=True,
        is_revealed=is_sunday_reveal,
        rival_status_label=(
            "Resultado 2v2 Revelado (Dom 23:59)"
            if is_sunday_reveal
            else "Dúo Rival en progreso / Entrenando • Oculto hasta Dom 23:59"
        ),
        projected_elo_stake=24,
        end_date=now_utc + timedelta(days=max(1, 6 - now_utc.weekday())),
    )


@router.post(
    "/duels/2v2/invite",
    response_model=ActiveDuo2v2DuelResponse,
    status_code=status.HTTP_200_OK,
)
async def invite_partner_2v2_duel(
    payload: DuoInvitePartnerRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ActiveDuo2v2DuelResponse:
    """
    Vincula un compañero para el Duelo 2v2 por Parejas de la semana.
    """
    partner_clean = payload.partner_username.strip().lstrip("@")
    duo_clean = payload.duo_name.strip() or f"Dúo {current_user.username} & {partner_clean}"
    _USER_DUO_PARTNERS[str(current_user.id)] = (partner_clean, duo_clean)
    return await get_active_2v2_duo_duel(current_user=current_user, db=db)
