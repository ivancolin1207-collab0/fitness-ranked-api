from __future__ import annotations

"""Esquemas Pydantic v2 para Leaderboards, Matchmaking ELO, Buscador de Usuarios y Duelos 1v1."""

from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field

from app.core.elo_engine import CompetitionType, MetricTarget, RankedTier


class LeaderboardRowResponse(BaseModel):
    rank: int
    user_id: UUID
    username: str
    full_name: Optional[str] = None
    tier: RankedTier
    current_elo: int
    peak_elo: int
    wins: int
    losses: int
    active_streak: int
    dots_normalized_volume: float
    lbm_allometric_score: float
    avg_compliance_pct: float


class LeaderboardResponse(BaseModel):
    season_id: str
    competition_type: CompetitionType
    metric_target: MetricTarget
    generated_at: datetime
    entries: list[LeaderboardRowResponse]


class OpponentSearchResultResponse(BaseModel):
    user_id: UUID
    username: str
    full_name: Optional[str] = None
    tier: RankedTier
    current_elo: int
    weekly_lbm_score: float
    weekly_dots_score: float


class DuelInviteByUsernameRequest(BaseModel):
    opponent_username: str = Field(..., min_length=3, max_length=32)
    season_id: str = Field(default="2026-S4", pattern=r"^[A-Za-z0-9_-]{3,32}$")
    metric_target: MetricTarget = MetricTarget.LBM_ALLOMETRIC_RATIO


class DuelMatchmakeRequest(BaseModel):
    season_id: str = Field(default="2026-S4", pattern=r"^[A-Za-z0-9_-]{3,32}$")
    elo_window: int = Field(default=100, ge=25, le=1000)
    metric_target: MetricTarget = MetricTarget.LBM_ALLOMETRIC_RATIO


class SymmetricWeeklyChallengeExercise(BaseModel):
    movement_pattern: str
    exercise_name: str
    target_sets: int
    target_reps: int
    target_rpe: float
    challenger_prescribed_weight_kg: float
    opponent_prescribed_weight_kg: float
    parity_note: str


class ActiveDuelLiveResponse(BaseModel):
    competition_id: UUID
    season_id: str
    matchmaking_mode: str
    metric_target: MetricTarget
    challenger_user_id: UUID
    challenger_username: str
    challenger_elo: int
    challenger_tier: str
    challenger_lbm_score: float
    challenger_dots_score: float
    challenger_rpe_compliance_pct: float
    challenger_discipline_multiplier: float = 1.12
    challenger_sleep_bonus_pct: float = 6.0
    challenger_consistency_bonus_pct: float = 4.0
    challenger_strain_balance_pct: float = 92.0
    challenger_effective_score: float = 0.0
    opponent_user_id: UUID
    opponent_username: str
    opponent_elo: int
    opponent_tier: str
    opponent_lbm_score: float
    opponent_dots_score: float
    opponent_rpe_compliance_pct: float
    opponent_discipline_multiplier: float = 1.08
    opponent_effective_score: float = 0.0
    is_blind_duel: bool = True
    is_revealed: bool = False
    rival_status_label: str = "En progreso / Entrenando • Se revela Domingo 23:59"
    symmetric_challenge: list[SymmetricWeeklyChallengeExercise] = Field(default_factory=list)
    projected_elo_stake: int
    start_date: datetime
    end_date: datetime


class DuoPairMemberSchema(BaseModel):
    user_id: Optional[UUID] = None
    username: str
    elo: int = 1200
    tier: str = "Plata"
    lbm_score: float = 0.0
    dots_score: float = 0.0
    discipline_multiplier: float = 1.10
    status_label: str = "Entrenando • Activo"


class ActiveDuo2v2DuelResponse(BaseModel):
    duo_duel_id: str
    season_id: str = "2026-S4"
    ally_duo_name: str
    ally_member_a: DuoPairMemberSchema
    ally_member_b: DuoPairMemberSchema
    ally_combined_lbm_score: float
    ally_combined_dots_score: float
    ally_avg_discipline_multiplier: float
    ally_effective_total: float
    rival_duo_name: str
    rival_member_a: DuoPairMemberSchema
    rival_member_b: DuoPairMemberSchema
    rival_combined_lbm_score: float
    rival_combined_dots_score: float
    rival_avg_discipline_multiplier: float
    rival_effective_total: float
    is_blind_duel: bool = True
    is_revealed: bool = False
    rival_status_label: str = "Dúo Rival en progreso / Entrenando • Oculto hasta Dom 23:59"
    projected_elo_stake: int = 24
    end_date: datetime


class DuoInvitePartnerRequest(BaseModel):
    partner_username: str = Field(..., min_length=2, max_length=32)
    duo_name: str = Field(default="Apex Twin Barbell", min_length=2, max_length=60)


class Duel1v1ResolutionRequest(BaseModel):
    season_id: str = Field(default="2026-S4", pattern=r"^[A-Za-z0-9_-]{3,32}$")
    challenger_user_id: UUID
    opponent_user_id: UUID
    metric_target: MetricTarget = MetricTarget.LBM_ALLOMETRIC_RATIO


class Duel1v1ResolutionResponse(BaseModel):
    competition_id: UUID
    season_id: str
    metric_target: MetricTarget
    challenger_user_id: UUID
    challenger_score: float
    challenger_elo_before: int
    challenger_elo_after: int
    challenger_delta: int
    opponent_user_id: UUID
    opponent_score: float
    opponent_elo_before: int
    opponent_elo_after: int
    opponent_delta: int
    resolved_at: datetime


class SquadMemberEntry(BaseModel):
    user_id: Optional[UUID] = None
    username: str
    role: str = "MEMBER"
    weekly_lbm_score: float
    weekly_dots_score: float
    weekly_compliance_pct: float


class SquadLeaderboardEntryResponse(BaseModel):
    rank: int
    team_id: UUID
    name: str
    tag: str
    member_count: int
    total_lbm_allometric_score: float
    total_dots_score: float
    avg_consistency_pct: float
    combined_squad_points: float
    is_user_squad: bool = False
    members: list[SquadMemberEntry] = Field(default_factory=list)


class SquadJoinOrCreateRequest(BaseModel):
    squad_name: str = Field(..., min_length=2, max_length=60)
    squad_tag: str = Field(default="APEX", min_length=2, max_length=8)
