class FitdaysExtractedMetricsModel {
  final double weightKg;
  final double fatPercentage;
  final double muscleMassKg;
  final double skeletalMusclePct;
  final int visceralFat;
  final double bodyWaterPct;
  final int bmr;
  final double ocrConfidence;
  final String sourceProvider;

  const FitdaysExtractedMetricsModel({
    required this.weightKg,
    required this.fatPercentage,
    required this.muscleMassKg,
    required this.skeletalMusclePct,
    required this.visceralFat,
    required this.bodyWaterPct,
    required this.bmr,
    this.ocrConfidence = 1.0,
    this.sourceProvider = 'MANUAL_FORM',
  });

  factory FitdaysExtractedMetricsModel.fromJson(Map<String, dynamic> json) {
    return FitdaysExtractedMetricsModel(
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 75.0,
      fatPercentage: (json['fat_percentage'] as num?)?.toDouble() ?? 15.0,
      muscleMassKg: (json['muscle_mass_kg'] as num?)?.toDouble() ?? 58.0,
      skeletalMusclePct:
          (json['skeletal_muscle_pct'] as num?)?.toDouble() ?? 42.0,
      visceralFat: (json['visceral_fat'] as num?)?.toInt() ?? 6,
      bodyWaterPct: (json['body_water_pct'] as num?)?.toDouble() ?? 60.0,
      bmr: (json['bmr'] as num?)?.toInt() ?? 1750,
      ocrConfidence: (json['ocr_confidence'] as num?)?.toDouble() ?? 1.0,
      sourceProvider: (json['source_provider'] as String?) ?? 'FITDAYS_OCR',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'weight_kg': weightKg,
      'fat_percentage': fatPercentage,
      'muscle_mass_kg': muscleMassKg,
      'skeletal_muscle_pct': skeletalMusclePct,
      'visceral_fat': visceralFat,
      'body_water_pct': bodyWaterPct,
      'bmr': bmr,
      'ocr_confidence': ocrConfidence,
      'source_provider': sourceProvider,
    };
  }
}

class BiometricRecord {
  final String id;
  final String userId;
  final double weightKg;
  final double fatPercentage;
  final double muscleMassKg;
  final double skeletalMusclePct;
  final int visceralFat;
  final double bodyWaterPct;
  final int bmr;
  final double leanBodyMassKg;
  final double ocrConfidence;
  final String sourceProvider;
  final DateTime capturedAt;

  const BiometricRecord({
    required this.id,
    required this.userId,
    required this.weightKg,
    required this.fatPercentage,
    required this.muscleMassKg,
    required this.skeletalMusclePct,
    required this.visceralFat,
    required this.bodyWaterPct,
    required this.bmr,
    required this.leanBodyMassKg,
    required this.ocrConfidence,
    required this.sourceProvider,
    required this.capturedAt,
  });

  factory BiometricRecord.fromJson(Map<String, dynamic> json) {
    final double weight = (json['weight_kg'] as num?)?.toDouble() ?? 75.0;
    final double fat = (json['fat_percentage'] as num?)?.toDouble() ?? 15.0;
    final double computedLbm = json['lean_body_mass_kg'] != null
        ? (json['lean_body_mass_kg'] as num).toDouble()
        : double.parse((weight * (1.0 - (fat / 100.0))).toStringAsFixed(2));
    final String rawCaptured = (json['captured_at'] as String?) ?? '';

    return BiometricRecord(
      id: (json['id'] as String?) ?? '',
      userId: (json['user_id'] as String?) ?? '',
      weightKg: weight,
      fatPercentage: fat,
      muscleMassKg: (json['muscle_mass_kg'] as num?)?.toDouble() ?? 58.0,
      skeletalMusclePct:
          (json['skeletal_muscle_pct'] as num?)?.toDouble() ?? 42.0,
      visceralFat: (json['visceral_fat'] as num?)?.toInt() ?? 6,
      bodyWaterPct: (json['body_water_pct'] as num?)?.toDouble() ?? 60.0,
      bmr: (json['bmr'] as num?)?.toInt() ?? 1750,
      leanBodyMassKg: computedLbm,
      ocrConfidence: (json['ocr_confidence'] as num?)?.toDouble() ?? 1.0,
      sourceProvider: (json['source_provider'] as String?) ?? 'MANUAL_FORM',
      capturedAt: DateTime.tryParse(rawCaptured) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'weight_kg': weightKg,
      'fat_percentage': fatPercentage,
      'muscle_mass_kg': muscleMassKg,
      'skeletal_muscle_pct': skeletalMusclePct,
      'visceral_fat': visceralFat,
      'body_water_pct': bodyWaterPct,
      'bmr': bmr,
      'lean_body_mass_kg': leanBodyMassKg,
      'ocr_confidence': ocrConfidence,
      'source_provider': sourceProvider,
      'captured_at': capturedAt.toIso8601String(),
    };
  }
}

class WearableMetricRecord {
  final DateTime date;
  final double strainScore;
  final double recoveryScore;
  final double hrvMs;
  final int restingHr;
  final int avgHr;
  final int maxHr;
  final double sleepHours;
  final double sleepEfficiencyPct;
  final String sourceDevice;

  // Métricas específicas polimórficas por ecosistema Wearable
  /// Nivel de Estrés Whoop (escala 0.0 a 3.0: Bajo / Medio / Alto)
  final double whoopStressLevel;

  /// Monitor de Salud Whoop (ej. 5 de 5 métricas dentro del rango)
  final int whoopHealthMetricsInRange;

  /// Nivel de Estrés Huawei GT (escala 0 a 100)
  final int huaweiStressScore;

  /// Puntuación TruSleep Huawei (0 a 100)
  final int huaweiTruSleepScore;

  /// VO2Max Huawei GT (ml/kg/min)
  final double huaweiVo2Max;

  /// Samsung Galaxy Watch Energy Score (0 a 100)
  final int samsungEnergyScore;

  /// Samsung BIA % Músculo Esquelético y % Grasa
  final double samsungBiaMusclePct;
  final double samsungBiaFatPct;

  /// Apple Watch 3 Anillos (Moverse kcal, Ejercicio min, De Pie h)
  final int appleMoveKcal;
  final int appleExerciseMinutes;
  final int appleStandHours;

  const WearableMetricRecord({
    required this.date,
    required this.strainScore,
    required this.recoveryScore,
    required this.hrvMs,
    required this.restingHr,
    required this.avgHr,
    required this.maxHr,
    required this.sleepHours,
    required this.sleepEfficiencyPct,
    required this.sourceDevice,
    this.whoopStressLevel = 1.4,
    this.whoopHealthMetricsInRange = 5,
    this.huaweiStressScore = 42,
    this.huaweiTruSleepScore = 84,
    this.huaweiVo2Max = 51.0,
    this.samsungEnergyScore = 78,
    this.samsungBiaMusclePct = 43.5,
    this.samsungBiaFatPct = 14.2,
    this.appleMoveKcal = 680,
    this.appleExerciseMinutes = 48,
    this.appleStandHours = 12,
  });

  factory WearableMetricRecord.fromJson(Map<String, dynamic> json) {
    final String rawDate = (json['date'] as String?) ?? '';
    final double rec = (json['recovery_score'] as num?)?.toDouble() ?? 75.0;
    final double sleepEff =
        (json['sleep_efficiency_pct'] as num?)?.toDouble() ?? 85.0;
    final double inferredWhoopStress =
        (json['whoop_stress_level'] as num?)?.toDouble() ??
            (rec < 40.0 ? 2.2 : (rec < 65.0 ? 1.5 : 0.9));

    return WearableMetricRecord(
      date: DateTime.tryParse(rawDate) ?? DateTime.now(),
      strainScore: (json['strain_score'] as num?)?.toDouble() ?? 9.6,
      recoveryScore: rec,
      hrvMs: (json['hrv_ms'] as num?)?.toDouble() ?? 65.0,
      restingHr: (json['resting_hr'] as num?)?.toInt() ?? 56,
      avgHr: (json['avg_hr'] as num?)?.toInt() ?? 68,
      maxHr: (json['max_hr'] as num?)?.toInt() ?? 165,
      sleepHours: (json['sleep_hours'] as num?)?.toDouble() ?? 7.2,
      sleepEfficiencyPct: sleepEff,
      sourceDevice: (json['source_device'] as String?) ?? 'WHOOP',
      whoopStressLevel: inferredWhoopStress,
      whoopHealthMetricsInRange:
          (json['whoop_health_metrics_in_range'] as num?)?.toInt() ?? 5,
      huaweiStressScore:
          (json['huawei_stress_score'] as num?)?.toInt() ??
              (100 - rec.round()).clamp(15, 95),
      huaweiTruSleepScore:
          (json['huawei_trusleep_score'] as num?)?.toInt() ??
              sleepEff.round().clamp(40, 100),
      huaweiVo2Max: (json['huawei_vo2_max'] as num?)?.toDouble() ?? 52.0,
      samsungEnergyScore:
          (json['samsung_energy_score'] as num?)?.toInt() ?? rec.round(),
      samsungBiaMusclePct:
          (json['samsung_bia_muscle_pct'] as num?)?.toDouble() ?? 43.8,
      samsungBiaFatPct:
          (json['samsung_bia_fat_pct'] as num?)?.toDouble() ?? 13.8,
      appleMoveKcal: (json['apple_move_kcal'] as num?)?.toInt() ?? 720,
      appleExerciseMinutes:
          (json['apple_exercise_minutes'] as num?)?.toInt() ?? 52,
      appleStandHours: (json['apple_stand_hours'] as num?)?.toInt() ?? 12,
    );
  }

  WearableMetricRecord copyWith({
    DateTime? date,
    double? strainScore,
    double? recoveryScore,
    double? hrvMs,
    int? restingHr,
    int? avgHr,
    int? maxHr,
    double? sleepHours,
    double? sleepEfficiencyPct,
    String? sourceDevice,
    double? whoopStressLevel,
    int? whoopHealthMetricsInRange,
    int? huaweiStressScore,
    int? huaweiTruSleepScore,
    double? huaweiVo2Max,
    int? samsungEnergyScore,
    double? samsungBiaMusclePct,
    double? samsungBiaFatPct,
    int? appleMoveKcal,
    int? appleExerciseMinutes,
    int? appleStandHours,
  }) {
    return WearableMetricRecord(
      date: date ?? this.date,
      strainScore: strainScore ?? this.strainScore,
      recoveryScore: recoveryScore ?? this.recoveryScore,
      hrvMs: hrvMs ?? this.hrvMs,
      restingHr: restingHr ?? this.restingHr,
      avgHr: avgHr ?? this.avgHr,
      maxHr: maxHr ?? this.maxHr,
      sleepHours: sleepHours ?? this.sleepHours,
      sleepEfficiencyPct: sleepEfficiencyPct ?? this.sleepEfficiencyPct,
      sourceDevice: sourceDevice ?? this.sourceDevice,
      whoopStressLevel: whoopStressLevel ?? this.whoopStressLevel,
      whoopHealthMetricsInRange:
          whoopHealthMetricsInRange ?? this.whoopHealthMetricsInRange,
      huaweiStressScore: huaweiStressScore ?? this.huaweiStressScore,
      huaweiTruSleepScore: huaweiTruSleepScore ?? this.huaweiTruSleepScore,
      huaweiVo2Max: huaweiVo2Max ?? this.huaweiVo2Max,
      samsungEnergyScore: samsungEnergyScore ?? this.samsungEnergyScore,
      samsungBiaMusclePct: samsungBiaMusclePct ?? this.samsungBiaMusclePct,
      samsungBiaFatPct: samsungBiaFatPct ?? this.samsungBiaFatPct,
      appleMoveKcal: appleMoveKcal ?? this.appleMoveKcal,
      appleExerciseMinutes: appleExerciseMinutes ?? this.appleExerciseMinutes,
      appleStandHours: appleStandHours ?? this.appleStandHours,
    );
  }

  Map<String, dynamic> toSyncJson() {
    final String ymd =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    // Si el dispositivo no está soportado por un backend antiguo, mapear de forma segura
    final String backendDevice =
        (sourceDevice == 'SAMSUNG_WATCH' || sourceDevice == 'APPLE_WATCH')
            ? 'HEALTH_CONNECT'
            : sourceDevice;
    return <String, dynamic>{
      'date': ymd,
      'strain_score': strainScore.clamp(0.0, 21.0),
      'recovery_score': recoveryScore.clamp(0.0, 100.0),
      'hrv_ms': hrvMs.clamp(5.0, 300.0),
      'resting_hr': restingHr.clamp(25, 140),
      'avg_hr': avgHr.clamp(30, 220),
      'max_hr': (maxHr < avgHr ? avgHr + 25 : maxHr).clamp(40, 240),
      'sleep_hours': sleepHours.clamp(0.0, 24.0),
      'sleep_efficiency_pct': sleepEfficiencyPct.clamp(0.0, 100.0),
      'source_device': backendDevice,
    };
  }
}

class HydrationLogEntryModel {
  final int amountMl;
  final String formattedTime;
  final DateTime loggedAt;

  const HydrationLogEntryModel({
    required this.amountMl,
    required this.formattedTime,
    required this.loggedAt,
  });

  factory HydrationLogEntryModel.fromJson(Map<String, dynamic> json) {
    final String rawAt = (json['logged_at'] as String?) ?? '';
    return HydrationLogEntryModel(
      amountMl: (json['amount_ml'] as num?)?.toInt() ?? 250,
      formattedTime: (json['formatted_time'] as String?) ?? '09:00 AM',
      loggedAt: DateTime.tryParse(rawAt) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'amount_ml': amountMl,
      'formatted_time': formattedTime,
      'logged_at': loggedAt.toIso8601String(),
    };
  }
}

class HydrationStatusModel {
  final String date;
  final int totalMl;
  final int recommendedGoalMl;
  final double completionPct;
  final List<HydrationLogEntryModel> logs;

  const HydrationStatusModel({
    required this.date,
    required this.totalMl,
    required this.recommendedGoalMl,
    required this.completionPct,
    required this.logs,
  });

  factory HydrationStatusModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawLogs =
        (json['logs'] as List<dynamic>?) ?? <dynamic>[];
    final int tot = (json['total_ml'] as num?)?.toInt() ?? 0;
    final int goal =
        ((json['recommended_goal_ml'] as num?)?.toInt() ?? 2800).clamp(1500, 6500);
    return HydrationStatusModel(
      date: (json['date'] as String?) ?? '',
      totalMl: tot,
      recommendedGoalMl: goal,
      completionPct: (json['completion_pct'] as num?)?.toDouble() ??
          ((tot / goal) * 100.0).clamp(0.0, 150.0),
      logs: rawLogs
          .whereType<Map<String, dynamic>>()
          .map(HydrationLogEntryModel.fromJson)
          .toList(),
    );
  }
}
