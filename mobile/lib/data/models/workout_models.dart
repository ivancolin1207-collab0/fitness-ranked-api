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
      setNumber: (json['set_number'] as num).toInt(),
      prescribedWeightKg: (json['prescribed_weight_kg'] as num).toDouble(),
      prescribedReps: (json['prescribed_reps'] as num).toInt(),
      prescribedRpe: (json['prescribed_rpe'] as num).toDouble(),
      restSeconds: json['rest_seconds'] != null
          ? (json['rest_seconds'] as num).toInt()
          : 150,
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
      adjustmentRationale: (json['adjustment_rationale'] as String?) ?? '',
      safetyGuardrailTriggered:
          (json['safety_guardrail_triggered'] as bool?) ?? false,
      updatedSets: rawSets
          .map(
            (dynamic item) =>
                PrescribedSetModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class WorkoutSetModel {
  final String id;
  final String exerciseId;
  final String exerciseName;
  final int setNumber;
  final double prescribedWeightKg;
  final int prescribedReps;
  final double prescribedRpe;
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
    required this.setNumber,
    required this.prescribedWeightKg,
    required this.prescribedReps,
    required this.prescribedRpe,
    this.actualWeightKg,
    this.actualReps,
    this.actualRpe,
    this.estimated1RmKg,
    this.completed = false,
    this.aiRecalculated = false,
  });

  WorkoutSetModel copyWith({
    double? prescribedWeightKg,
    int? prescribedReps,
    double? prescribedRpe,
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
      setNumber: setNumber,
      prescribedWeightKg: prescribedWeightKg ?? this.prescribedWeightKg,
      prescribedReps: prescribedReps ?? this.prescribedReps,
      prescribedRpe: prescribedRpe ?? this.prescribedRpe,
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
    return WorkoutSetModel(
      id: json['id'] as String,
      exerciseId: json['exercise_id'] as String,
      exerciseName:
          (json['exercise_name'] as String?) ?? fallbackExerciseName,
      setNumber: (json['set_number'] as num).toInt(),
      prescribedWeightKg: (json['prescribed_weight'] as num).toDouble(),
      prescribedReps: (json['prescribed_reps'] as num).toInt(),
      prescribedRpe: (json['prescribed_rpe'] as num).toDouble(),
      actualWeightKg: json['actual_weight'] != null
          ? (json['actual_weight'] as num).toDouble()
          : null,
      actualReps:
          json['reps'] != null ? (json['reps'] as num).toInt() : null,
      actualRpe:
          json['rpe'] != null ? (json['rpe'] as num).toDouble() : null,
      estimated1RmKg: json['estimated_1rm_kg'] != null
          ? (json['estimated_1rm_kg'] as num).toDouble()
          : null,
      completed: (json['completed'] as bool?) ?? false,
      aiRecalculated: (json['ai_recalculated'] as bool?) ?? false,
    );
  }
}

class RoutineExerciseItemModel {
  final String id;
  final String exerciseId;
  final String exerciseName;
  final String muscleGroup;
  final int displayOrder;
  final int targetSets;
  final int targetReps;
  final double targetWeightKg;
  final double targetRpe;
  final int restSeconds;

  const RoutineExerciseItemModel({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.muscleGroup,
    required this.displayOrder,
    required this.targetSets,
    required this.targetReps,
    required this.targetWeightKg,
    required this.targetRpe,
    required this.restSeconds,
  });

  factory RoutineExerciseItemModel.fromJson(Map<String, dynamic> json) {
    return RoutineExerciseItemModel(
      id: json['id'] as String,
      exerciseId: json['exercise_id'] as String,
      exerciseName: json['exercise_name'] as String,
      muscleGroup: (json['muscle_group'] as String?) ?? 'General',
      displayOrder: (json['display_order'] as num).toInt(),
      targetSets: (json['target_sets'] as num).toInt(),
      targetReps: (json['target_reps'] as num).toInt(),
      targetWeightKg: (json['target_weight_kg'] as num).toDouble(),
      targetRpe: (json['target_rpe'] as num).toDouble(),
      restSeconds: json['rest_seconds'] != null
          ? (json['rest_seconds'] as num).toInt()
          : 150,
    );
  }

  Map<String, dynamic> toInputJson() {
    return <String, dynamic>{
      'exercise_name': exerciseName,
      'muscle_group': muscleGroup,
      'category': 'hipertrofia',
      'target_sets': targetSets,
      'target_reps': targetReps,
      'target_weight_kg': targetWeightKg,
      'target_rpe': targetRpe,
      'rest_seconds': restSeconds,
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
    const List<String> names = <String>[
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    if (dayOfWeek >= 1 && dayOfWeek <= 7) {
      return names[dayOfWeek - 1];
    }
    return 'Día $dayOfWeek';
  }

  factory RoutineTemplateModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawExercises =
        (json['exercises'] as List<dynamic>?) ?? <dynamic>[];
    return RoutineTemplateModel(
      id: json['id'] as String,
      dayOfWeek: (json['day_of_week'] as num).toInt(),
      name: json['name'] as String,
      focusGroup: (json['focus_group'] as String?) ?? '',
      isActive: (json['is_active'] as bool?) ?? true,
      exercises: rawExercises
          .map(
            (dynamic item) => RoutineExerciseItemModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
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
    required this.sets,
  });

  factory WorkoutSessionModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawSets =
        (json['sets'] as List<dynamic>?) ?? <dynamic>[];
    return WorkoutSessionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      date: DateTime.parse(json['date'] as String),
      status: json['status'] as String,
      totalVolumeKg: (json['total_volume_kg'] as num).toDouble(),
      dotsNormalizedVolume:
          (json['dots_normalized_volume'] as num).toDouble(),
      lbmAllometricScore:
          (json['lbm_allometric_score'] as num).toDouble(),
      intensityRpe: json['intensity_rpe'] != null
          ? (json['intensity_rpe'] as num).toDouble()
          : null,
      compliancePct: (json['compliance_pct'] as num).toDouble(),
      sets: rawSets
          .map(
            (dynamic item) =>
                WorkoutSetModel.fromJson(item as Map<String, dynamic>),
          )
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
    return TodayWorkoutPlanModel(
      hasRoutines: (json['has_routines'] as bool?) ?? false,
      isRollover: (json['is_rollover'] as bool?) ?? false,
      rolloverFromDay: json['rollover_from_day'] != null
          ? (json['rollover_from_day'] as num).toInt()
          : null,
      coachRolloverBanner: json['coach_rollover_banner'] as String?,
      activeRoutine: json['active_routine'] != null
          ? RoutineTemplateModel.fromJson(
              json['active_routine'] as Map<String, dynamic>,
            )
          : null,
      activeWorkout: json['active_workout'] != null
          ? WorkoutSessionModel.fromJson(
              json['active_workout'] as Map<String, dynamic>,
            )
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
    return SetExecutionFeedbackResponseModel(
      workoutId: json['workout_id'] as String,
      exerciseId: json['exercise_id'] as String,
      setNumber: (json['set_number'] as num).toInt(),
      estimated1RmKg: (json['estimated_1rm_kg'] as num).toDouble(),
      sessionRawVolumeKg: (json['session_raw_volume_kg'] as num).toDouble(),
      sessionDotsVolume: (json['session_dots_volume'] as num).toDouble(),
      sessionLbmAllometricScore:
          (json['session_lbm_allometric_score'] as num).toDouble(),
      compliancePct: (json['compliance_pct'] as num).toDouble(),
      projectedEloDelta: (json['projected_elo_delta'] as num).toInt(),
      currentElo: (json['current_elo'] as num).toInt(),
      currentTier: json['current_tier'] as String,
      geminiPrescription: AdaptivePrescriptionModel.fromJson(
        json['gemini_prescription'] as Map<String, dynamic>,
      ),
    );
  }
}
