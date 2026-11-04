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
    opponent_user_id: UUID
    opponent_username: str
    opponent_elo: int
    opponent_tier: str
    opponent_lbm_score: float
    opponent_dots_score: float
    opponent_rpe_compliance_pct: float
    projected_elo_stake: int
    start_date: datetime
    end_date: datetime


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
