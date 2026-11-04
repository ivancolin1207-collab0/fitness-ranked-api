class UserProfileModel {
  final String id;
  final String username;
  final String? fullName;
  final String maskedEmail;
  final DateTime? birthDate;
  final int? ageYears;
  final String biologicalSex;
  final double heightCm;
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
    required this.heightCm,
    required this.trainingGoal,
    required this.preferredWearable,
    required this.unitSystem,
    required this.onboardingCompleted,
    required this.currentElo,
    required this.currentTier,
    required this.createdAt,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as String,
      username: json['username'] as String,
      fullName: json['full_name'] as String?,
      maskedEmail: (json['masked_email'] as String?) ?? '',
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'].toString())
          : null,
      ageYears: json['age_years'] != null
          ? (json['age_years'] as num).toInt()
          : null,
      biologicalSex: (json['biological_sex'] as String?) ?? 'MALE',
      heightCm: json['height_cm'] != null
          ? (json['height_cm'] as num).toDouble()
          : 175.0,
      trainingGoal: (json['training_goal'] as String?) ?? 'HIPERTROFIA',
      preferredWearable: (json['preferred_wearable'] as String?) ?? 'WHOOP',
      unitSystem: (json['unit_system'] as String?) ?? 'KG',
      onboardingCompleted: (json['onboarding_completed'] as bool?) ?? false,
      currentElo: json['current_elo'] != null
          ? (json['current_elo'] as num).toInt()
          : 1200,
      currentTier: (json['current_tier'] as String?) ?? 'Plata',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class AuthTokenResponseModel {
  final String accessToken;
  final String tokenType;
  final int expiresInSeconds;

  const AuthTokenResponseModel({
    required this.accessToken,
    required this.tokenType,
    required this.expiresInSeconds,
  });

  factory AuthTokenResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthTokenResponseModel(
      accessToken: json['access_token'] as String,
      tokenType: (json['token_type'] as String?) ?? 'bearer',
      expiresInSeconds: json['expires_in_seconds'] != null
          ? (json['expires_in_seconds'] as num).toInt()
          : 3600,
    );
  }
}

class ProfileSetupRequestModel {
  final String? username;
  final String fullName;
  final DateTime birthDate;
  final String biologicalSex;
  final double heightCm;
  final String trainingGoal;
  final String preferredWearable;
  final String unitSystem;

  const ProfileSetupRequestModel({
    this.username,
    required this.fullName,
    required this.birthDate,
    required this.biologicalSex,
    required this.heightCm,
    required this.trainingGoal,
    required this.preferredWearable,
    required this.unitSystem,
  });

  Map<String, dynamic> toJson() {
    final String ymd =
        '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}';
    return <String, dynamic>{
      if (username != null && username!.trim().isNotEmpty)
        'username': username!.trim(),
      'full_name': fullName.trim(),
      'birth_date': ymd,
      'biological_sex': biologicalSex,
      'height_cm': heightCm,
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
