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
      weightKg: (json['weight_kg'] as num).toDouble(),
      fatPercentage: (json['fat_percentage'] as num).toDouble(),
      muscleMassKg: (json['muscle_mass_kg'] as num).toDouble(),
      skeletalMusclePct: (json['skeletal_muscle_pct'] as num).toDouble(),
      visceralFat: (json['visceral_fat'] as num).toInt(),
      bodyWaterPct: json['body_water_pct'] != null
          ? (json['body_water_pct'] as num).toDouble()
          : 60.0,
      bmr: (json['bmr'] as num).toInt(),
      ocrConfidence: json['ocr_confidence'] != null
          ? (json['ocr_confidence'] as num).toDouble()
          : 1.0,
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
    final double weight = (json['weight_kg'] as num).toDouble();
    final double fat = (json['fat_percentage'] as num).toDouble();
    final double computedLbm = json['lean_body_mass_kg'] != null
        ? (json['lean_body_mass_kg'] as num).toDouble()
        : double.parse((weight * (1.0 - (fat / 100.0))).toStringAsFixed(2));

    return BiometricRecord(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      weightKg: weight,
      fatPercentage: fat,
      muscleMassKg: (json['muscle_mass_kg'] as num).toDouble(),
      skeletalMusclePct: (json['skeletal_muscle_pct'] as num).toDouble(),
      visceralFat: (json['visceral_fat'] as num).toInt(),
      bodyWaterPct: json['body_water_pct'] != null
          ? (json['body_water_pct'] as num).toDouble()
          : 60.0,
      bmr: (json['bmr'] as num).toInt(),
      leanBodyMassKg: computedLbm,
      ocrConfidence: json['ocr_confidence'] != null
          ? (json['ocr_confidence'] as num).toDouble()
          : 1.0,
      sourceProvider: (json['source_provider'] as String?) ?? 'MANUAL_FORM',
      capturedAt: DateTime.parse(json['captured_at'] as String),
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
  });

  factory WearableMetricRecord.fromJson(Map<String, dynamic> json) {
    return WearableMetricRecord(
      date: DateTime.parse(json['date'] as String),
      strainScore: (json['strain_score'] as num).toDouble(),
      recoveryScore: (json['recovery_score'] as num).toDouble(),
      hrvMs: json['hrv_ms'] != null ? (json['hrv_ms'] as num).toDouble() : 0.0,
      restingHr:
          json['resting_hr'] != null ? (json['resting_hr'] as num).toInt() : 0,
      avgHr: (json['avg_hr'] as num).toInt(),
      maxHr: (json['max_hr'] as num).toInt(),
      sleepHours: (json['sleep_hours'] as num).toDouble(),
      sleepEfficiencyPct: json['sleep_efficiency_pct'] != null
          ? (json['sleep_efficiency_pct'] as num).toDouble()
          : 90.0,
      sourceDevice: (json['source_device'] as String?) ?? 'WHOOP',
    );
  }

  Map<String, dynamic> toSyncJson() {
    final String ymd =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return <String, dynamic>{
      'date': ymd,
      'strain_score': strainScore,
      'recovery_score': recoveryScore,
      'hrv_ms': hrvMs,
      'resting_hr': restingHr,
      'avg_hr': avgHr,
      'max_hr': maxHr,
      'sleep_hours': sleepHours,
      'sleep_efficiency_pct': sleepEfficiencyPct,
      'source_device': sourceDevice,
    };
  }
}
