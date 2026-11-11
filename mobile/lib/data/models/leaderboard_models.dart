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

class SymmetricChallengeExerciseModel {
  final String movementPattern;
  final String exerciseName;
  final int targetSets;
  final int targetReps;
  final double targetRpe;
  final double challengerPrescribedWeightKg;
  final double opponentPrescribedWeightKg;
  final String parityNote;

  const SymmetricChallengeExerciseModel({
    required this.movementPattern,
    required this.exerciseName,
    required this.targetSets,
    required this.targetReps,
    required this.targetRpe,
    required this.challengerPrescribedWeightKg,
    required this.opponentPrescribedWeightKg,
    required this.parityNote,
  });

  factory SymmetricChallengeExerciseModel.fromJson(Map<String, dynamic> json) {
    return SymmetricChallengeExerciseModel(
      movementPattern:
          (json['movement_pattern'] as String?) ?? 'Patrón Compuesto',
      exerciseName:
          (json['exercise_name'] as String?) ?? 'Barbell Back Squat',
      targetSets: (json['target_sets'] as num?)?.toInt() ?? 4,
      targetReps: (json['target_reps'] as num?)?.toInt() ?? 8,
      targetRpe: (json['target_rpe'] as num?)?.toDouble() ?? 8.0,
      challengerPrescribedWeightKg:
          (json['challenger_prescribed_weight_kg'] as num?)?.toDouble() ?? 0.0,
      opponentPrescribedWeightKg:
          (json['opponent_prescribed_weight_kg'] as num?)?.toDouble() ?? 0.0,
      parityNote: (json['parity_note'] as String?) ??
          'Escala alométrica LBM^0.67 equitativa (100% paridad relativa)',
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
  final double challengerDisciplineMultiplier;
  final double challengerSleepBonusPct;
  final double challengerConsistencyBonusPct;
  final double challengerStrainBalancePct;
  final double challengerEffectiveScore;
  final String opponentId;
  final String opponentUsername;
  final int opponentElo;
  final String opponentTier;
  final double opponentLbmScore;
  final double opponentDotsScore;
  final double opponentRpeCompliancePct;
  final double opponentDisciplineMultiplier;
  final double opponentEffectiveScore;
  final bool isBlindDuel;
  final bool isRevealed;
  final String rivalStatusLabel;
  final List<SymmetricChallengeExerciseModel> symmetricChallenge;
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
    this.challengerDisciplineMultiplier = 1.14,
    this.challengerSleepBonusPct = 7.0,
    this.challengerConsistencyBonusPct = 4.5,
    this.challengerStrainBalancePct = 93.0,
    this.challengerEffectiveScore = 0.0,
    required this.opponentId,
    required this.opponentUsername,
    required this.opponentElo,
    required this.opponentTier,
    required this.opponentLbmScore,
    required this.opponentDotsScore,
    required this.opponentRpeCompliancePct,
    this.opponentDisciplineMultiplier = 1.10,
    this.opponentEffectiveScore = 0.0,
    this.isBlindDuel = true,
    this.isRevealed = false,
    this.rivalStatusLabel =
        'En progreso / Entrenando • Se revela Domingo 23:59',
    this.symmetricChallenge = const <SymmetricChallengeExerciseModel>[],
    required this.projectedEloStake,
  });

  factory HeadToHeadDuelModel.fromJson(Map<String, dynamic> json) {
    final double lbmA =
        (json['challenger_lbm_score'] as num?)?.toDouble() ?? 0.0;
    final double multA =
        (json['challenger_discipline_multiplier'] as num?)?.toDouble() ?? 1.0;
    final double lbmB =
        (json['opponent_lbm_score'] as num?)?.toDouble() ?? 0.0;
    final double multB =
        (json['opponent_discipline_multiplier'] as num?)?.toDouble() ?? 1.0;
    final String chName =
        (json['challenger_username'] as String?) ?? 'atleta';
    final List<dynamic> rawChallenges =
        (json['symmetric_challenge'] as List<dynamic>?) ?? <dynamic>[];

    final List<SymmetricChallengeExerciseModel> parsedChallenges = rawChallenges
        .whereType<Map<String, dynamic>>()
        .map(SymmetricChallengeExerciseModel.fromJson)
        .toList();

    return HeadToHeadDuelModel(
      competitionId: (json['competition_id'] as String?) ?? '',
      seasonId: (json['season_id'] as String?) ?? '2026-S4',
      metricTarget:
          (json['metric_target'] as String?) ?? 'LBM_ALLOMETRIC_RATIO',
      challengerId:
          (json['challenger_user_id'] ?? json['challenger_id'] ?? '').toString(),
      challengerUsername: chName,
      challengerElo: (json['challenger_elo'] as num?)?.toInt() ?? 1200,
      challengerTier: (json['challenger_tier'] as String?) ?? 'Plata',
      challengerLbmScore: lbmA,
      challengerDotsScore:
          (json['challenger_dots_score'] as num?)?.toDouble() ?? 0.0,
      challengerRpeCompliancePct:
          (json['challenger_rpe_compliance_pct'] as num?)?.toDouble() ?? 100.0,
      challengerDisciplineMultiplier: multA,
      challengerSleepBonusPct:
          (json['challenger_sleep_bonus_pct'] as num?)?.toDouble() ?? 0.0,
      challengerConsistencyBonusPct:
          (json['challenger_consistency_bonus_pct'] as num?)?.toDouble() ?? 0.0,
      challengerStrainBalancePct:
          (json['challenger_strain_balance_pct'] as num?)?.toDouble() ?? 0.0,
      challengerEffectiveScore:
          (json['challenger_effective_score'] as num?)?.toDouble() ??
              double.parse((lbmA * multA).toStringAsFixed(2)),
      opponentId:
          (json['opponent_user_id'] ?? json['opponent_id'] ?? '').toString(),
      opponentUsername: (json['opponent_username'] as String?) ?? 'rival',
      opponentElo: (json['opponent_elo'] as num?)?.toInt() ?? 1200,
      opponentTier: (json['opponent_tier'] as String?) ?? 'Plata',
      opponentLbmScore: lbmB,
      opponentDotsScore:
          (json['opponent_dots_score'] as num?)?.toDouble() ?? 0.0,
      opponentRpeCompliancePct:
          (json['opponent_rpe_compliance_pct'] as num?)?.toDouble() ?? 100.0,
      opponentDisciplineMultiplier: multB,
      opponentEffectiveScore:
          (json['opponent_effective_score'] as num?)?.toDouble() ??
              double.parse((lbmB * multB).toStringAsFixed(2)),
      isBlindDuel: (json['is_blind_duel'] as bool?) ?? true,
      isRevealed: (json['is_revealed'] as bool?) ?? false,
      rivalStatusLabel: (json['rival_status_label'] as String?) ??
          'En progreso / Entrenando • Se revela Domingo 23:59',
      symmetricChallenge: parsedChallenges,
      projectedEloStake: (json['projected_elo_stake'] as num?)?.toInt() ?? 16,
    );
  }
}

class DuoPairMemberModel {
  final String username;
  final int elo;
  final String tier;
  final double lbmScore;
  final double dotsScore;
  final double disciplineMultiplier;
  final String statusLabel;

  const DuoPairMemberModel({
    required this.username,
    required this.elo,
    required this.tier,
    required this.lbmScore,
    required this.dotsScore,
    required this.disciplineMultiplier,
    required this.statusLabel,
  });

  factory DuoPairMemberModel.fromJson(Map<String, dynamic> json) {
    return DuoPairMemberModel(
      username: (json['username'] as String?) ?? 'atleta',
      elo: (json['elo'] as num?)?.toInt() ?? 1200,
      tier: (json['tier'] as String?) ?? 'Plata',
      lbmScore: (json['lbm_score'] as num?)?.toDouble() ?? 0.0,
      dotsScore: (json['dots_score'] as num?)?.toDouble() ?? 0.0,
      disciplineMultiplier:
          (json['discipline_multiplier'] as num?)?.toDouble() ?? 1.0,
      statusLabel: (json['status_label'] as String?) ?? 'Entrenando • Activo',
    );
  }
}

class ActiveDuo2v2DuelModel {
  final String duoDuelId;
  final String seasonId;
  final String allyDuoName;
  final DuoPairMemberModel allyMemberA;
  final DuoPairMemberModel allyMemberB;
  final double allyCombinedLbmScore;
  final double allyCombinedDotsScore;
  final double allyAvgDisciplineMultiplier;
  final double allyEffectiveTotal;
  final String rivalDuoName;
  final DuoPairMemberModel rivalMemberA;
  final DuoPairMemberModel rivalMemberB;
  final double rivalCombinedLbmScore;
  final double rivalCombinedDotsScore;
  final double rivalAvgDisciplineMultiplier;
  final double rivalEffectiveTotal;
  final bool isBlindDuel;
  final bool isRevealed;
  final String rivalStatusLabel;
  final int projectedEloStake;

  const ActiveDuo2v2DuelModel({
    required this.duoDuelId,
    required this.seasonId,
    required this.allyDuoName,
    required this.allyMemberA,
    required this.allyMemberB,
    required this.allyCombinedLbmScore,
    required this.allyCombinedDotsScore,
    required this.allyAvgDisciplineMultiplier,
    required this.allyEffectiveTotal,
    required this.rivalDuoName,
    required this.rivalMemberA,
    required this.rivalMemberB,
    required this.rivalCombinedLbmScore,
    required this.rivalCombinedDotsScore,
    required this.rivalAvgDisciplineMultiplier,
    required this.rivalEffectiveTotal,
    required this.isBlindDuel,
    required this.isRevealed,
    required this.rivalStatusLabel,
    required this.projectedEloStake,
  });

  factory ActiveDuo2v2DuelModel.fromJson(Map<String, dynamic> json) {
    const DuoPairMemberModel emptyMember = DuoPairMemberModel(
      username: '--',
      elo: 1200,
      tier: 'Plata',
      lbmScore: 0.0,
      dotsScore: 0.0,
      disciplineMultiplier: 1.0,
      statusLabel: 'Sin datos',
    );
    final DuoPairMemberModel aA = json['ally_member_a'] is Map<String, dynamic>
        ? DuoPairMemberModel.fromJson(
            json['ally_member_a'] as Map<String, dynamic>,
          )
        : emptyMember;
    final DuoPairMemberModel aB = json['ally_member_b'] is Map<String, dynamic>
        ? DuoPairMemberModel.fromJson(
            json['ally_member_b'] as Map<String, dynamic>,
          )
        : emptyMember;
    final DuoPairMemberModel rA = json['rival_member_a'] is Map<String, dynamic>
        ? DuoPairMemberModel.fromJson(
            json['rival_member_a'] as Map<String, dynamic>,
          )
        : emptyMember;
    final DuoPairMemberModel rB = json['rival_member_b'] is Map<String, dynamic>
        ? DuoPairMemberModel.fromJson(
            json['rival_member_b'] as Map<String, dynamic>,
          )
        : emptyMember;

    return ActiveDuo2v2DuelModel(
      duoDuelId: (json['duo_duel_id'] as String?) ?? '',
      seasonId: (json['season_id'] as String?) ?? '2026-S4',
      allyDuoName: (json['ally_duo_name'] as String?) ?? 'Dúo Aliado',
      allyMemberA: aA,
      allyMemberB: aB,
      allyCombinedLbmScore:
          (json['ally_combined_lbm_score'] as num?)?.toDouble() ??
              (aA.lbmScore + aB.lbmScore),
      allyCombinedDotsScore:
          (json['ally_combined_dots_score'] as num?)?.toDouble() ??
              (aA.dotsScore + aB.dotsScore),
      allyAvgDisciplineMultiplier:
          (json['ally_avg_discipline_multiplier'] as num?)?.toDouble() ?? 1.0,
      allyEffectiveTotal:
          (json['ally_effective_total'] as num?)?.toDouble() ?? 0.0,
      rivalDuoName: (json['rival_duo_name'] as String?) ?? 'Dúo Rival',
      rivalMemberA: rA,
      rivalMemberB: rB,
      rivalCombinedLbmScore:
          (json['rival_combined_lbm_score'] as num?)?.toDouble() ??
              (rA.lbmScore + rB.lbmScore),
      rivalCombinedDotsScore:
          (json['rival_combined_dots_score'] as num?)?.toDouble() ??
              (rA.dotsScore + rB.dotsScore),
      rivalAvgDisciplineMultiplier:
          (json['rival_avg_discipline_multiplier'] as num?)?.toDouble() ?? 1.0,
      rivalEffectiveTotal:
          (json['rival_effective_total'] as num?)?.toDouble() ?? 0.0,
      isBlindDuel: (json['is_blind_duel'] as bool?) ?? true,
      isRevealed: (json['is_revealed'] as bool?) ?? false,
      rivalStatusLabel: (json['rival_status_label'] as String?) ??
          'Dúo Rival en progreso / Entrenando • Oculto hasta Dom 23:59',
      projectedEloStake: (json['projected_elo_stake'] as num?)?.toInt() ?? 24,
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
      weeklyLbmScore: (json['weekly_lbm_score'] as num?)?.toDouble() ?? 0.0,
      weeklyDotsScore:
          (json['weekly_dots_score'] as num?)?.toDouble() ?? 0.0,
      weeklyCompliancePct:
          (json['weekly_compliance_pct'] as num?)?.toDouble() ?? 0.0,
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
      name: (json['name'] as String?) ?? 'Squad',
      tag: (json['tag'] as String?) ?? 'SQD',
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      totalLbmAllometricScore:
          (json['total_lbm_allometric_score'] as num?)?.toDouble() ?? 0.0,
      totalDotsScore: (json['total_dots_score'] as num?)?.toDouble() ?? 0.0,
      avgConsistencyPct:
          (json['avg_consistency_pct'] as num?)?.toDouble() ?? 0.0,
      combinedSquadPoints:
          (json['combined_squad_points'] as num?)?.toDouble() ?? 0.0,
      isUserSquad: (json['is_user_squad'] as bool?) ?? false,
      members: rawMembers
          .whereType<Map<String, dynamic>>()
          .map(SquadMemberModel.fromJson)
          .toList(),
    );
  }
}
