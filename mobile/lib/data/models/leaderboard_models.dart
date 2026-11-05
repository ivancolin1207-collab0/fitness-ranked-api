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
      rank: (json['rank'] as num?)?.toInt() ?? 1,
      userId: (json['user_id'] as String?) ?? '',
      username: (json['username'] as String?) ?? 'atleta',
      tier: (json['tier'] as String?) ?? 'Plata',
      currentElo: (json['current_elo'] as num?)?.toInt() ?? 1200,
      peakElo: (json['peak_elo'] as num?)?.toInt() ?? 1200,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      activeStreak: (json['active_streak'] as num?)?.toInt() ?? 0,
      dotsNormalizedVolume:
          (json['dots_normalized_volume'] as num?)?.toDouble() ?? 0.0,
      lbmAllometricScore:
          (json['lbm_allometric_score'] as num?)?.toDouble() ?? 0.0,
      avgCompliancePct:
          (json['avg_compliance_pct'] as num?)?.toDouble() ?? 100.0,
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
    final String rawGenerated = (json['generated_at'] as String?) ?? '';
    return LeaderboardResponseModel(
      seasonId: (json['season_id'] as String?) ?? '2026-S4',
      competitionType: (json['competition_type'] as String?) ?? 'GLOBAL',
      metricTarget:
          (json['metric_target'] as String?) ?? 'LBM_ALLOMETRIC_RATIO',
      generatedAt: DateTime.tryParse(rawGenerated) ?? DateTime.now(),
      entries: rawEntries
          .whereType<Map<String, dynamic>>()
          .map(LeaderboardRowModel.fromJson)
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
      userId: (json['user_id'] as String?) ?? '',
      username: (json['username'] as String?) ?? 'atleta',
      fullName: json['full_name'] as String?,
      currentElo: (json['current_elo'] as num?)?.toInt() ?? 1200,
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
      competitionId: (json['competition_id'] as String?) ?? '',
      seasonId: (json['season_id'] as String?) ?? '2026-S4',
      metricTarget:
          (json['metric_target'] as String?) ?? 'LBM_ALLOMETRIC_RATIO',
      challengerId: (json['challenger_id'] as String?) ?? '',
      challengerUsername: (json['challenger_username'] as String?) ?? 'atleta',
      challengerElo: (json['challenger_elo'] as num?)?.toInt() ?? 1200,
      challengerTier: (json['challenger_tier'] as String?) ?? 'Plata',
      challengerLbmScore:
          (json['challenger_lbm_score'] as num?)?.toDouble() ?? 0.0,
      challengerDotsScore:
          (json['challenger_dots_score'] as num?)?.toDouble() ?? 0.0,
      challengerRpeCompliancePct:
          (json['challenger_rpe_compliance_pct'] as num?)?.toDouble() ?? 100.0,
      opponentId: (json['opponent_id'] as String?) ?? '',
      opponentUsername: (json['opponent_username'] as String?) ?? 'rival',
      opponentElo: (json['opponent_elo'] as num?)?.toInt() ?? 1200,
      opponentTier: (json['opponent_tier'] as String?) ?? 'Plata',
      opponentLbmScore:
          (json['opponent_lbm_score'] as num?)?.toDouble() ?? 0.0,
      opponentDotsScore:
          (json['opponent_dots_score'] as num?)?.toDouble() ?? 0.0,
      opponentRpeCompliancePct:
          (json['opponent_rpe_compliance_pct'] as num?)?.toDouble() ?? 100.0,
      projectedEloStake: (json['projected_elo_stake'] as num?)?.toInt() ?? 16,
    );
  }
}

class SquadMemberModel {
  final String? userId;
  final String username;
  final String role;
  final double weeklyLbmScore;
  final double weeklyDotsScore;
  final double weeklyCompliancePct;

  const SquadMemberModel({
    this.userId,
    required this.username,
    required this.role,
    required this.weeklyLbmScore,
    required this.weeklyDotsScore,
    required this.weeklyCompliancePct,
  });

  factory SquadMemberModel.fromJson(Map<String, dynamic> json) {
    return SquadMemberModel(
      userId: json['user_id']?.toString(),
      username: (json['username'] as String?) ?? 'atleta',
      role: (json['role'] as String?) ?? 'MEMBER',
      weeklyLbmScore: (json['weekly_lbm_score'] as num?)?.toDouble() ?? 380.0,
      weeklyDotsScore:
          (json['weekly_dots_score'] as num?)?.toDouble() ?? 4650.0,
      weeklyCompliancePct:
          (json['weekly_compliance_pct'] as num?)?.toDouble() ?? 95.0,
    );
  }
}

class SquadLeaderboardEntryModel {
  final int rank;
  final String teamId;
  final String name;
  final String tag;
  final int memberCount;
  final double totalLbmAllometricScore;
  final double totalDotsScore;
  final double avgConsistencyPct;
  final double combinedSquadPoints;
  final bool isUserSquad;
  final List<SquadMemberModel> members;

  const SquadLeaderboardEntryModel({
    required this.rank,
    required this.teamId,
    required this.name,
    required this.tag,
    required this.memberCount,
    required this.totalLbmAllometricScore,
    required this.totalDotsScore,
    required this.avgConsistencyPct,
    required this.combinedSquadPoints,
    required this.isUserSquad,
    required this.members,
  });

  factory SquadLeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawMembers =
        (json['members'] as List<dynamic>?) ?? <dynamic>[];
    return SquadLeaderboardEntryModel(
      rank: (json['rank'] as num?)?.toInt() ?? 1,
      teamId: json['team_id']?.toString() ?? '',
      name: (json['name'] as String?) ?? 'Apex Squad',
      tag: (json['tag'] as String?) ?? 'APEX',
      memberCount: (json['member_count'] as num?)?.toInt() ?? 4,
      totalLbmAllometricScore:
          (json['total_lbm_allometric_score'] as num?)?.toDouble() ?? 1550.0,
      totalDotsScore: (json['total_dots_score'] as num?)?.toDouble() ?? 18900.0,
      avgConsistencyPct:
          (json['avg_consistency_pct'] as num?)?.toDouble() ?? 95.0,
      combinedSquadPoints:
          (json['combined_squad_points'] as num?)?.toDouble() ?? 1530.0,
      isUserSquad: (json['is_user_squad'] as bool?) ?? false,
      members: rawMembers
          .whereType<Map<String, dynamic>>()
          .map(SquadMemberModel.fromJson)
          .toList(),
    );
  }
}
