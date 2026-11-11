class UserProfileModel {
  final String id;
  final String username;
  final String? fullName;
  final String maskedEmail;
  final DateTime? birthDate;
  final int? ageYears;
  final String sex;
  final String biologicalSex;
  final double? heightCm;
  final double? weightKg;
  final double? bodyFatPct;
  final double? lbmKg;
  final String? biometricSignature;
  final String trainingGoal;
  final String preferredWearable;
  final String unitSystem;
  final bool onboardingCompleted;
  final int currentElo;
  final String currentTier;
  final DateTime createdAt;

  const UserProfileModel({
    required this.id,
    required this.username,
    this.fullName,
    required this.maskedEmail,
    this.birthDate,
    this.ageYears,
    required this.biologicalSex,
    String? sex,
    this.heightCm,
    this.weightKg,
    this.bodyFatPct,
    this.lbmKg,
    this.biometricSignature,
    required this.trainingGoal,
    required this.preferredWearable,
    required this.unitSystem,
    required this.onboardingCompleted,
    required this.currentElo,
    required this.currentTier,
    required this.createdAt,
  }) : sex = sex ??
            ((biologicalSex == 'FEMALE' || biologicalSex == 'female')
                ? 'female'
                : 'male');

  static String _normalizeSexCode(Object? rawSex, Object? rawBioSex) {
    final String candidate =
        '${rawSex ?? ''} ${rawBioSex ?? ''}'.toLowerCase().trim();
    if (candidate.contains('fem') ||
        candidate.contains('mujer') ||
        candidate == 'f') {
      return 'female';
    }
    return 'male';
  }

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final String resolvedSex =
        _normalizeSexCode(json['sex'], json['biological_sex']);
    final String resolvedBioSex = resolvedSex == 'female' ? 'FEMALE' : 'MALE';
    return UserProfileModel(
      id: (json['id'] as String?) ?? '',
      username: (json['username'] as String?) ?? 'atleta',
      fullName: json['full_name'] as String?,
      maskedEmail: (json['masked_email'] as String?) ?? '',
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'].toString())
          : null,
      ageYears: (json['age_years'] as num?)?.toInt(),
      sex: resolvedSex,
      biologicalSex: resolvedBioSex,
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      bodyFatPct: (json['body_fat_pct'] as num?)?.toDouble(),
      lbmKg: (json['lbm_kg'] as num?)?.toDouble(),
      biometricSignature: json['biometric_signature'] as String?,
      trainingGoal: (json['training_goal'] as String?) ?? 'HIPERTROFIA',
      preferredWearable: (json['preferred_wearable'] as String?) ?? 'WHOOP',
      unitSystem: (json['unit_system'] as String?) ?? 'KG',
      onboardingCompleted: (json['onboarding_completed'] as bool?) ?? false,
      currentElo: (json['current_elo'] as num?)?.toInt() ?? 1200,
      currentTier: (json['current_tier'] as String?) ?? 'Plata',
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'username': username,
      'full_name': fullName,
      'masked_email': maskedEmail,
      'birth_date': birthDate?.toIso8601String(),
      'age_years': ageYears,
      'sex': sex,
      'biological_sex': biologicalSex,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'body_fat_pct': bodyFatPct,
      'lbm_kg': lbmKg,
      'biometric_signature': biometricSignature,
      'training_goal': trainingGoal,
      'preferred_wearable': preferredWearable,
      'unit_system': unitSystem,
      'onboarding_completed': onboardingCompleted,
      'current_elo': currentElo,
      'current_tier': currentTier,
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserProfileModel copyWith({
    String? id,
    String? username,
    String? fullName,
    String? maskedEmail,
    DateTime? birthDate,
    int? ageYears,
    String? sex,
    String? biologicalSex,
    double? heightCm,
    double? weightKg,
    double? bodyFatPct,
    double? lbmKg,
    String? biometricSignature,
    String? trainingGoal,
    String? preferredWearable,
    String? unitSystem,
    bool? onboardingCompleted,
    int? currentElo,
    String? currentTier,
    DateTime? createdAt,
  }) {
    final String nextBio = biologicalSex ?? this.biologicalSex;
    final String nextSex = sex ??
        (biologicalSex != null
            ? _normalizeSexCode(null, biologicalSex)
            : this.sex);
    return UserProfileModel(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      maskedEmail: maskedEmail ?? this.maskedEmail,
      birthDate: birthDate ?? this.birthDate,
      ageYears: ageYears ?? this.ageYears,
      sex: nextSex,
      biologicalSex: nextBio,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      bodyFatPct: bodyFatPct ?? this.bodyFatPct,
      lbmKg: lbmKg ?? this.lbmKg,
      biometricSignature: biometricSignature ?? this.biometricSignature,
      trainingGoal: trainingGoal ?? this.trainingGoal,
      preferredWearable: preferredWearable ?? this.preferredWearable,
      unitSystem: unitSystem ?? this.unitSystem,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      currentElo: currentElo ?? this.currentElo,
      currentTier: currentTier ?? this.currentTier,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class AuthTokenResponseModel {
  final String accessToken;
  final String tokenType;
  final int expiresInSeconds;
  final UserProfileModel? user;

  const AuthTokenResponseModel({
    required this.accessToken,
    required this.tokenType,
    required this.expiresInSeconds,
    this.user,
  });

  factory AuthTokenResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthTokenResponseModel(
      accessToken: (json['access_token'] as String?) ?? '',
      tokenType: (json['token_type'] as String?) ?? 'bearer',
      expiresInSeconds:
          (json['expires_in_seconds'] as num?)?.toInt() ?? 31536000,
      user: json['user'] is Map<String, dynamic>
          ? UserProfileModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ProfileSetupRequestModel {
  final String? username;
  final String fullName;
  final DateTime birthDate;
  final String biologicalSex;
  final double heightCm;
  final double? weightKg;
  final double? bodyFatPct;
  final String trainingGoal;
  final String preferredWearable;
  final String unitSystem;

  const ProfileSetupRequestModel({
    this.username,
    required this.fullName,
    required this.birthDate,
    required this.biologicalSex,
    required this.heightCm,
    this.weightKg,
    this.bodyFatPct,
    required this.trainingGoal,
    required this.preferredWearable,
    required this.unitSystem,
  });

  Map<String, dynamic> toJson() {
    final String ymd =
        '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}';
    final bool isFemale = biologicalSex.toUpperCase() == 'FEMALE' ||
        biologicalSex.toLowerCase() == 'female';
    return <String, dynamic>{
      if (username != null && username!.trim().isNotEmpty)
        'username': username!.trim(),
      'full_name': fullName.trim(),
      'birth_date': ymd,
      'sex': isFemale ? 'female' : 'male',
      'biological_sex': isFemale ? 'FEMALE' : 'MALE',
      'height_cm': heightCm,
      if (weightKg != null) 'weight_kg': weightKg,
      if (bodyFatPct != null) 'body_fat_pct': bodyFatPct,
      'training_goal': trainingGoal,
      'preferred_wearable': preferredWearable,
      'unit_system': unitSystem,
    };
  }
}

class ServerHealthCheckModel {
  final bool isOnline;
  final String activeBaseUrl;
  final int? statusCode;
  final int? latencyMs;
  final String message;

  const ServerHealthCheckModel({
    required this.isOnline,
    required this.activeBaseUrl,
    this.statusCode,
    this.latencyMs,
    required this.message,
  });
}
