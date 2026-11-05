class PrescribedSetModel {
  final int setNumber;
  final double prescribedWeightKg;
  final int prescribedReps;
  final double prescribedRpe;
  final int restSeconds;

  const PrescribedSetModel({
    required this.setNumber,
    required this.prescribedWeightKg,
    required this.prescribedReps,
    required this.prescribedRpe,
    required this.restSeconds,
  });

  factory PrescribedSetModel.fromJson(Map<String, dynamic> json) {
    return PrescribedSetModel(
      setNumber: (json['set_number'] as num?)?.toInt() ?? 1,
      prescribedWeightKg:
          (json['prescribed_weight_kg'] as num?)?.toDouble() ?? 60.0,
      prescribedReps: (json['prescribed_reps'] as num?)?.toInt() ?? 8,
      prescribedRpe: (json['prescribed_rpe'] as num?)?.toDouble() ?? 8.0,
      restSeconds: (json['rest_seconds'] as num?)?.toInt() ?? 150,
    );
  }
}

class AdaptivePrescriptionModel {
  final String readinessZone;
  final String adjustmentRationale;
  final bool safetyGuardrailTriggered;
  final List<PrescribedSetModel> updatedSets;

  const AdaptivePrescriptionModel({
    required this.readinessZone,
    required this.adjustmentRationale,
    required this.safetyGuardrailTriggered,
    required this.updatedSets,
  });

  factory AdaptivePrescriptionModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawSets =
        (json['updated_sets'] as List<dynamic>?) ?? <dynamic>[];
    return AdaptivePrescriptionModel(
      readinessZone: (json['readiness_zone'] as String?) ?? 'YELLOW_MAINTENANCE',
      adjustmentRationale: (json['adjustment_rationale'] as String?) ??
          'Gemini Coach adaptará las cargas y repeticiones de tus series según tu RPE real.',
      safetyGuardrailTriggered:
          (json['safety_guardrail_triggered'] as bool?) ?? false,
      updatedSets: rawSets
          .whereType<Map<String, dynamic>>()
          .map(PrescribedSetModel.fromJson)
          .toList(),
    );
  }
}

class WorkoutSetModel {
  final String id;
  final String exerciseId;
  final String exerciseName;
  final String exerciseKey;
  final int setNumber;
  final double prescribedWeightKg;
  final int prescribedReps;
  final double prescribedRpe;
  final int restSeconds;
  final String tempo;
  final String coachingCue;
  final double? actualWeightKg;
  final int? actualReps;
  final double? actualRpe;
  final double? estimated1RmKg;
  final bool completed;
  final bool aiRecalculated;

  const WorkoutSetModel({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    this.exerciseKey = 'bench_press_barbell',
    required this.setNumber,
    required this.prescribedWeightKg,
    required this.prescribedReps,
    required this.prescribedRpe,
    this.restSeconds = 90,
    this.tempo = '3-0-1-0',
    this.coachingCue =
        'Controla la fase excéntrica y mantén estabilidad escapular',
    this.actualWeightKg,
    this.actualReps,
    this.actualRpe,
    this.estimated1RmKg,
    this.completed = false,
    this.aiRecalculated = false,
  });

  WorkoutSetModel copyWith({
    String? exerciseKey,
    double? prescribedWeightKg,
    int? prescribedReps,
    double? prescribedRpe,
    int? restSeconds,
    String? tempo,
    String? coachingCue,
    double? actualWeightKg,
    int? actualReps,
    double? actualRpe,
    double? estimated1RmKg,
    bool? completed,
    bool? aiRecalculated,
  }) {
    return WorkoutSetModel(
      id: id,
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      exerciseKey: exerciseKey ?? this.exerciseKey,
      setNumber: setNumber,
      prescribedWeightKg: prescribedWeightKg ?? this.prescribedWeightKg,
      prescribedReps: prescribedReps ?? this.prescribedReps,
      prescribedRpe: prescribedRpe ?? this.prescribedRpe,
      restSeconds: restSeconds ?? this.restSeconds,
      tempo: tempo ?? this.tempo,
      coachingCue: coachingCue ?? this.coachingCue,
      actualWeightKg: actualWeightKg ?? this.actualWeightKg,
      actualReps: actualReps ?? this.actualReps,
      actualRpe: actualRpe ?? this.actualRpe,
      estimated1RmKg: estimated1RmKg ?? this.estimated1RmKg,
      completed: completed ?? this.completed,
      aiRecalculated: aiRecalculated ?? this.aiRecalculated,
    );
  }

  factory WorkoutSetModel.fromJson(
    Map<String, dynamic> json, {
    String fallbackExerciseName = 'Ejercicio',
  }) {
    final num? rawPrescribedWeight =
        (json['prescribed_weight'] ?? json['prescribed_weight_kg']) as num?;
    final num? rawActualWeight =
        (json['actual_weight'] ?? json['actual_weight_kg']) as num?;
    final num? rawActualReps = (json['reps'] ?? json['actual_reps']) as num?;
    final num? rawActualRpe = (json['rpe'] ?? json['actual_rpe']) as num?;

    return WorkoutSetModel(
      id: (json['id'] as String?) ?? '',
      exerciseId: (json['exercise_id'] as String?) ?? '',
      exerciseName:
          (json['exercise_name'] as String?) ?? fallbackExerciseName,
      exerciseKey:
          (json['exercise_key'] as String?) ?? 'bench_press_barbell',
      setNumber: (json['set_number'] as num?)?.toInt() ?? 1,
      prescribedWeightKg: rawPrescribedWeight?.toDouble() ?? 60.0,
      prescribedReps: (json['prescribed_reps'] as num?)?.toInt() ?? 8,
      prescribedRpe: (json['prescribed_rpe'] as num?)?.toDouble() ?? 8.0,
      restSeconds: (json['rest_seconds'] as num?)?.toInt() ?? 90,
      tempo: (json['tempo'] as String?) ?? '3-0-1-0',
      coachingCue: (json['coaching_cue'] as String?) ??
          'Controla la fase excéntrica y mantén estabilidad escapular',
      actualWeightKg: rawActualWeight?.toDouble(),
      actualReps: rawActualReps?.toInt(),
      actualRpe: rawActualRpe?.toDouble(),
      estimated1RmKg: (json['estimated_1rm_kg'] as num?)?.toDouble(),
      completed: (json['completed'] as bool?) ?? false,
      aiRecalculated: (json['ai_recalculated'] as bool?) ?? false,
    );
  }
}

class RoutineExerciseItemModel {
  final String id;
  final String exerciseId;
  final String exerciseName;
  final String exerciseKey;
  final String muscleGroup;
  final int displayOrder;
  final int targetSets;
  final int targetReps;
  final String targetRepsRange;
  final double targetWeightKg;
  final double targetRpe;
  final int restSeconds;
  final String tempo;
  final String coachingCue;
  final String? progressionNote;

  const RoutineExerciseItemModel({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    this.exerciseKey = 'bench_press_barbell',
    required this.muscleGroup,
    required this.displayOrder,
    required this.targetSets,
    required this.targetReps,
    this.targetRepsRange = '8-10',
    required this.targetWeightKg,
    required this.targetRpe,
    required this.restSeconds,
    this.tempo = '3-0-1-0',
    this.coachingCue =
        'Controla la fase excéntrica y mantén estabilidad escapular',
    this.progressionNote,
  });

  factory RoutineExerciseItemModel.fromJson(Map<String, dynamic> json) {
    final String resolvedExerciseId =
        (json['exercise_id'] as String?) ?? (json['id'] as String?) ?? '';
    final String resolvedId =
        (json['id'] as String?) ?? resolvedExerciseId;
    final num? weightNum = (json['prescribed_weight_kg'] ??
        json['recommended_weight_kg'] ??
        json['base_weight_kg'] ??
        json['target_weight_kg']) as num?;
    final dynamic rawReps = json['target_reps'];
    int parsedReps = 8;
    String repsRange = (json['target_reps_range'] as String?) ?? '8-10';
    if (rawReps is num) {
      parsedReps = rawReps.toInt();
      if (json['target_reps_range'] == null) {
        repsRange = '$parsedReps';
      }
    } else if (rawReps is String) {
      repsRange = rawReps.trim();
      final RegExpMatch? m = RegExp(r'\d+').firstMatch(repsRange);
      parsedReps =
          (json['target_reps_int'] as num?)?.toInt() ??
              (m != null ? (int.tryParse(m.group(0)!) ?? 8) : 8);
    }

    return RoutineExerciseItemModel(
      id: resolvedId,
      exerciseId: resolvedExerciseId,
      exerciseName: ((json['exercise_name'] ?? json['name']) as String?) ??
          'Ejercicio',
      exerciseKey:
          (json['exercise_key'] as String?) ?? 'bench_press_barbell',
      muscleGroup: (json['muscle_group'] as String?) ?? 'General',
      displayOrder:
          ((json['display_order'] ?? json['order']) as num?)?.toInt() ?? 1,
      targetSets: (json['target_sets'] as num?)?.toInt() ?? 4,
      targetReps: parsedReps,
      targetRepsRange: repsRange,
      targetWeightKg: weightNum?.toDouble() ?? 60.0,
      targetRpe:
          ((json['target_rpe'] ?? json['rpe_target']) as num?)?.toDouble() ??
              8.0,
      restSeconds: (json['rest_seconds'] as num?)?.toInt() ?? 90,
      tempo: (json['tempo'] as String?) ?? '3-0-1-0',
      coachingCue: (json['coaching_cue'] as String?) ??
          'Controla la fase excéntrica y mantén estabilidad escapular',
      progressionNote: (json['progression_note'] as String?) ??
          (json['weekly_variant_suggestion'] != null
              ? 'Rotación semanal sugerida: ${json['weekly_variant_suggestion']}'
              : (json['notes'] as String?)),
    );
  }

  Map<String, dynamic> toInputJson() {
    return <String, dynamic>{
      'exercise_name': exerciseName,
      'exercise_key': exerciseKey,
      'muscle_group': muscleGroup,
      'category': 'hipertrofia',
      'target_sets': targetSets,
      'target_reps': targetReps,
      'base_weight_kg': targetWeightKg,
      'target_weight_kg': targetWeightKg,
      'target_rpe': targetRpe,
      'rest_seconds': restSeconds,
      'tempo': tempo,
      'coaching_cue': coachingCue,
    };
  }
}

class RoutineTemplateModel {
  final String id;
  final int dayOfWeek;
  final String name;
  final String focusGroup;
  final bool isActive;
  final List<RoutineExerciseItemModel> exercises;

  const RoutineTemplateModel({
    required this.id,
    required this.dayOfWeek,
    required this.name,
    required this.focusGroup,
    required this.isActive,
    required this.exercises,
  });

  String get dayLabel {
    return 'Día $dayOfWeek';
  }

  factory RoutineTemplateModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawExercises =
        (json['exercises'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> rawTargetMuscles =
        (json['target_muscles'] as List<dynamic>?) ?? <dynamic>[];
    final String rawFocus = (json['focus_group'] as String?) ??
        (rawTargetMuscles.isNotEmpty
            ? rawTargetMuscles.map((dynamic e) => e.toString()).join(' & ')
            : '');
    final String resolvedId =
        (json['routine_template_id'] as String?) ??
            (json['id'] as String?) ??
            '';
    final int resolvedDay =
        ((json['day_of_week'] ?? json['day_number']) as num?)?.toInt() ?? 1;
    final String resolvedName =
        ((json['name'] ?? json['day_name']) as String?) ?? 'Día $resolvedDay';

    return RoutineTemplateModel(
      id: resolvedId,
      dayOfWeek: resolvedDay,
      name: resolvedName,
      focusGroup: rawFocus.trim().isEmpty ? 'General' : rawFocus,
      isActive: (json['is_active'] as bool?) ?? true,
      exercises: rawExercises
          .whereType<Map<String, dynamic>>()
          .map(RoutineExerciseItemModel.fromJson)
          .toList(),
    );
  }
}

class AiGeneratedRoutinePlanModel {
  final bool hasRoutine;
  final String routineName;
  final String weeklyFocus;
  final List<RoutineTemplateModel> days;

  const AiGeneratedRoutinePlanModel({
    required this.hasRoutine,
    required this.routineName,
    required this.weeklyFocus,
    required this.days,
  });

  factory AiGeneratedRoutinePlanModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> root = json['routine'] is Map<String, dynamic>
        ? json['routine'] as Map<String, dynamic>
        : json;
    final List<dynamic> rawDays =
        (root['days'] as List<dynamic>?) ?? <dynamic>[];
    final List<RoutineTemplateModel> parsedDays = rawDays
        .whereType<Map<String, dynamic>>()
        .map(RoutineTemplateModel.fromJson)
        .toList();
    final bool hasRoutineFlag =
        (root['has_routine'] as bool?) ?? parsedDays.isNotEmpty;
    return AiGeneratedRoutinePlanModel(
      hasRoutine: hasRoutineFlag && parsedDays.isNotEmpty,
      routineName: (root['routine_name'] as String?) ??
          'Hipertrofia Adaptativa Personalizada (Gemini IA)',
      weeklyFocus: (root['weekly_focus'] as String?) ??
          'Enfoque biomecánico adaptado a LBM',
      days: parsedDays,
    );
  }
}

class WorkoutSessionModel {
  final String id;
  final String userId;
  final DateTime date;
  final String status;
  final double totalVolumeKg;
  final double dotsNormalizedVolume;
  final double lbmAllometricScore;
  final double? intensityRpe;
  final double compliancePct;
  final String? aiPrescriptionNotes;
  final List<WorkoutSetModel> sets;

  const WorkoutSessionModel({
    required this.id,
    required this.userId,
    required this.date,
    required this.status,
    required this.totalVolumeKg,
    required this.dotsNormalizedVolume,
    required this.lbmAllometricScore,
    this.intensityRpe,
    required this.compliancePct,
    this.aiPrescriptionNotes,
    required this.sets,
  });

  factory WorkoutSessionModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawSets =
        (json['sets'] as List<dynamic>?) ?? <dynamic>[];
    final String rawDate = (json['date'] as String?) ?? '';
    return WorkoutSessionModel(
      id: (json['id'] as String?) ?? '',
      userId: (json['user_id'] as String?) ?? '',
      date: DateTime.tryParse(rawDate) ?? DateTime.now(),
      status: (json['status'] as String?) ?? 'in_progress',
      totalVolumeKg: (json['total_volume_kg'] as num?)?.toDouble() ?? 0.0,
      dotsNormalizedVolume:
          (json['dots_normalized_volume'] as num?)?.toDouble() ?? 0.0,
      lbmAllometricScore:
          (json['lbm_allometric_score'] as num?)?.toDouble() ?? 0.0,
      intensityRpe: (json['intensity_rpe'] as num?)?.toDouble(),
      compliancePct: (json['compliance_pct'] as num?)?.toDouble() ?? 100.0,
      aiPrescriptionNotes: json['ai_prescription_notes'] as String?,
      sets: rawSets
          .whereType<Map<String, dynamic>>()
          .map(WorkoutSetModel.fromJson)
          .toList(),
    );
  }
}

class TodayWorkoutPlanModel {
  final bool hasRoutines;
  final bool isRollover;
  final int? rolloverFromDay;
  final String? coachRolloverBanner;
  final RoutineTemplateModel? activeRoutine;
  final WorkoutSessionModel? activeWorkout;

  const TodayWorkoutPlanModel({
    required this.hasRoutines,
    required this.isRollover,
    this.rolloverFromDay,
    this.coachRolloverBanner,
    this.activeRoutine,
    this.activeWorkout,
  });

  factory TodayWorkoutPlanModel.fromJson(Map<String, dynamic> json) {
    final Object? rawRoutine = json['active_routine'];
    final Object? rawWorkout = json['active_workout'];
    return TodayWorkoutPlanModel(
      hasRoutines: (json['has_routines'] as bool?) ?? false,
      isRollover: (json['is_rollover'] as bool?) ?? false,
      rolloverFromDay: (json['rollover_from_day'] as num?)?.toInt(),
      coachRolloverBanner: json['coach_rollover_banner'] as String?,
      activeRoutine: rawRoutine is Map<String, dynamic>
          ? RoutineTemplateModel.fromJson(rawRoutine)
          : null,
      activeWorkout: rawWorkout is Map<String, dynamic>
          ? WorkoutSessionModel.fromJson(rawWorkout)
          : null,
    );
  }
}

class SetExecutionFeedbackRequestModel {
  final String exerciseId;
  final int setNumber;
  final bool completedBinaryUi;
  final double actualWeightKg;
  final int actualReps;
  final double actualRpe;

  const SetExecutionFeedbackRequestModel({
    required this.exerciseId,
    required this.setNumber,
    required this.completedBinaryUi,
    required this.actualWeightKg,
    required this.actualReps,
    required this.actualRpe,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'exercise_id': exerciseId,
      'set_number': setNumber,
      'completed_binary_ui': completedBinaryUi,
      'actual_weight_kg': actualWeightKg,
      'actual_reps': actualReps,
      'actual_rpe': actualRpe,
    };
  }
}

class SetExecutionFeedbackResponseModel {
  final String workoutId;
  final String exerciseId;
  final int setNumber;
  final double estimated1RmKg;
  final double sessionRawVolumeKg;
  final double sessionDotsVolume;
  final double sessionLbmAllometricScore;
  final double compliancePct;
  final int projectedEloDelta;
  final int currentElo;
  final String currentTier;
  final AdaptivePrescriptionModel geminiPrescription;

  const SetExecutionFeedbackResponseModel({
    required this.workoutId,
    required this.exerciseId,
    required this.setNumber,
    required this.estimated1RmKg,
    required this.sessionRawVolumeKg,
    required this.sessionDotsVolume,
    required this.sessionLbmAllometricScore,
    required this.compliancePct,
    required this.projectedEloDelta,
    required this.currentElo,
    required this.currentTier,
    required this.geminiPrescription,
  });

  factory SetExecutionFeedbackResponseModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final Object? rawPrescription = json['gemini_prescription'];
    return SetExecutionFeedbackResponseModel(
      workoutId: (json['workout_id'] as String?) ?? '',
      exerciseId: (json['exercise_id'] as String?) ?? '',
      setNumber: (json['set_number'] as num?)?.toInt() ?? 1,
      estimated1RmKg: (json['estimated_1rm_kg'] as num?)?.toDouble() ?? 0.0,
      sessionRawVolumeKg:
          (json['session_raw_volume_kg'] as num?)?.toDouble() ?? 0.0,
      sessionDotsVolume:
          (json['session_dots_volume'] as num?)?.toDouble() ?? 0.0,
      sessionLbmAllometricScore:
          (json['session_lbm_allometric_score'] as num?)?.toDouble() ?? 0.0,
      compliancePct: (json['compliance_pct'] as num?)?.toDouble() ?? 100.0,
      projectedEloDelta: (json['projected_elo_delta'] as num?)?.toInt() ?? 0,
      currentElo: (json['current_elo'] as num?)?.toInt() ?? 1200,
      currentTier: (json['current_tier'] as String?) ?? 'Plata',
      geminiPrescription: AdaptivePrescriptionModel.fromJson(
        rawPrescription is Map<String, dynamic>
            ? rawPrescription
            : <String, dynamic>{},
      ),
    );
  }
}
