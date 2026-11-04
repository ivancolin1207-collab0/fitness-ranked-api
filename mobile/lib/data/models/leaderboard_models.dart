class LeaderboardRowModel {
  final int rank;
  final String userId;
  final String username;
  final String tier;
  final int currentElo;
  final int peakElo;
  final int wins;
  final int losses;
  final int activeStreak;
  final double dotsNormalizedVolume;
  final double lbmAllometricScore;
  final double avgCompliancePct;

  const LeaderboardRowModel({
    required this.rank,
    required this.userId,
    required this.username,
    required this.tier,
    required this.currentElo,
    required this.peakElo,
    required this.wins,
    required this.losses,
    required this.activeStreak,
    required this.dotsNormalizedVolume,
    required this.lbmAllometricScore,
    required this.avgCompliancePct,
  });

  factory LeaderboardRowModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardRowModel(
      rank: (json['rank'] as num).toInt(),
      userId: json['user_id'] as String,
      username: json['username'] as String,
      tier: json['tier'] as String,
      currentElo: (json['current_elo'] as num).toInt(),
      peakElo: (json['peak_elo'] as num).toInt(),
      wins: (json['wins'] as num).toInt(),
      losses: (json['losses'] as num).toInt(),
      activeStreak: (json['active_streak'] as num).toInt(),
      dotsNormalizedVolume:
          (json['dots_normalized_volume'] as num).toDouble(),
      lbmAllometricScore:
          (json['lbm_allometric_score'] as num).toDouble(),
      avgCompliancePct: (json['avg_compliance_pct'] as num).toDouble(),
    );
  }
}

class LeaderboardResponseModel {
  final String seasonId;
  final String competitionType;
  final String metricTarget;
  final DateTime generatedAt;
  final List<LeaderboardRowModel> entries;

  const LeaderboardResponseModel({
    required this.seasonId,
    required this.competitionType,
    required this.metricTarget,
    required this.generatedAt,
    required this.entries,
  });

  factory LeaderboardResponseModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawEntries =
        (json['entries'] as List<dynamic>?) ?? <dynamic>[];
    return LeaderboardResponseModel(
      seasonId: json['season_id'] as String,
      competitionType: json['competition_type'] as String,
      metricTarget: json['metric_target'] as String,
      generatedAt: DateTime.parse(json['generated_at'] as String),
      entries: rawEntries
          .map(
            (dynamic item) =>
                LeaderboardRowModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class OpponentSearchResultModel {
  final String userId;
  final String username;
  final String? fullName;
  final int currentElo;
  final String tier;
  final String trainingGoal;

  const OpponentSearchResultModel({
    required this.userId,
    required this.username,
    this.fullName,
    required this.currentElo,
    required this.tier,
    required this.trainingGoal,
  });

  factory OpponentSearchResultModel.fromJson(Map<String, dynamic> json) {
    return OpponentSearchResultModel(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      fullName: json['full_name'] as String?,
      currentElo: (json['current_elo'] as num).toInt(),
      tier: (json['tier'] as String?) ?? 'Plata',
      trainingGoal: (json['training_goal'] as String?) ?? 'HIPERTROFIA',
    );
  }
}

class HeadToHeadDuelModel {
  final String competitionId;
  final String seasonId;
  final String metricTarget;
  final String challengerId;
  final String challengerUsername;
  final int challengerElo;
  final String challengerTier;
  final double challengerLbmScore;
  final double challengerDotsScore;
  final double challengerRpeCompliancePct;
  final String opponentId;
  final String opponentUsername;
  final int opponentElo;
  final String opponentTier;
  final double opponentLbmScore;
  final double opponentDotsScore;
  final double opponentRpeCompliancePct;
  final int projectedEloStake;

  const HeadToHeadDuelModel({
    required this.competitionId,
    required this.seasonId,
    required this.metricTarget,
    required this.challengerId,
    required this.challengerUsername,
    required this.challengerElo,
    required this.challengerTier,
    required this.challengerLbmScore,
    required this.challengerDotsScore,
    required this.challengerRpeCompliancePct,
    required this.opponentId,
    required this.opponentUsername,
    required this.opponentElo,
    required this.opponentTier,
    required this.opponentLbmScore,
    required this.opponentDotsScore,
    required this.opponentRpeCompliancePct,
    required this.projectedEloStake,
  });

  factory HeadToHeadDuelModel.fromJson(Map<String, dynamic> json) {
    return HeadToHeadDuelModel(
      competitionId: json['competition_id'] as String,
      seasonId: (json['season_id'] as String?) ?? '2026-S4',
      metricTarget:
          (json['metric_target'] as String?) ?? 'LBM_ALLOMETRIC_RATIO',
      challengerId: json['challenger_id'] as String,
      challengerUsername: json['challenger_username'] as String,
      challengerElo: (json['challenger_elo'] as num).toInt(),
      challengerTier: json['challenger_tier'] as String,
      challengerLbmScore: (json['challenger_lbm_score'] as num).toDouble(),
      challengerDotsScore: (json['challenger_dots_score'] as num).toDouble(),
      challengerRpeCompliancePct:
          (json['challenger_rpe_compliance_pct'] as num).toDouble(),
      opponentId: json['opponent_id'] as String,
      opponentUsername: json['opponent_username'] as String,
      opponentElo: (json['opponent_elo'] as num).toInt(),
      opponentTier: json['opponent_tier'] as String,
      opponentLbmScore: (json['opponent_lbm_score'] as num).toDouble(),
      opponentDotsScore: (json['opponent_dots_score'] as num).toDouble(),
      opponentRpeCompliancePct:
          (json['opponent_rpe_compliance_pct'] as num).toDouble(),
      projectedEloStake: (json['projected_elo_stake'] as num).toInt(),
    );
  }
}
