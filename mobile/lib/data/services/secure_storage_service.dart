import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_models.dart';
import '../models/biometric_models.dart';
import '../models/workout_models.dart';

class SecureStorageService {
  static const String _jwtKey = 'apexmetrix_jwt_token';
  static const String _userIdKey = 'apexmetrix_user_id';
  static const String _cachedProfileKey = 'apexmetrix_cached_user_profile_v1';
  static const String _unitKey = 'apexmetrix_unit_system';
  static const String _wearableKey = 'apexmetrix_preferred_wearable';
  static const String _apiBaseUrlKey = 'apexmetrix_cloud_api_url_v2';
  static const String _hydrationLogsPrefix = 'apexmetrix_hydration_logs_';
  static const String _userRoutinePrefix = 'user_routine_';
  static const String _userRoutineTemplatesPrefix = 'user_routine_templates_';
  static const String _userWearablePrefix = 'user_wearable_';
  static const String _userBiometricsPrefix = 'user_biometrics_';
  static const String _pairedBleIdPrefix = 'last_paired_ble_id_';
  static const String _pairedBleNamePrefix = 'last_paired_ble_name_';
  static const String _globalPairedBleIdKey = 'last_paired_ble_id';
  static const String _globalPairedBleNameKey = 'last_paired_ble_name';

  final FlutterSecureStorage _secureStorage;

  const SecureStorageService({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
                resetOnError: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  Future<void> saveJwtToken(String token) async {
    await _secureStorage.write(key: _jwtKey, value: token);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_jwtKey, token);
  }

  Future<String?> readJwtToken() async {
    try {
      final String? secureToken = await _secureStorage.read(key: _jwtKey);
      if (secureToken != null && secureToken.isNotEmpty) {
        return secureToken;
      }
    } catch (_) {}
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? fallbackToken = prefs.getString(_jwtKey);
    if (fallbackToken != null && fallbackToken.isNotEmpty) {
      return fallbackToken;
    }
    return null;
  }

  Future<void> saveUserId(String userId) async {
    await _secureStorage.write(key: _userIdKey, value: userId);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
  }

  Future<String?> readUserId() async {
    try {
      final String? secureId = await _secureStorage.read(key: _userIdKey);
      if (secureId != null && secureId.isNotEmpty) {
        return secureId;
      }
    } catch (_) {}
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  Future<void> saveUserProfileCache(UserProfileModel profile) async {
    final String encoded = jsonEncode(profile.toJson());
    try {
      await _secureStorage.write(key: _cachedProfileKey, value: encoded);
      if (profile.id.isNotEmpty) {
        await _secureStorage.write(key: _userIdKey, value: profile.id);
      }
    } catch (_) {}
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedProfileKey, encoded);
    if (profile.id.isNotEmpty) {
      await prefs.setString(_userIdKey, profile.id);
    }
  }

  Future<UserProfileModel?> readUserProfileCache() async {
    String? raw;
    try {
      raw = await _secureStorage.read(key: _cachedProfileKey);
    } catch (_) {}
    if (raw == null || raw.isEmpty) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      raw = prefs.getString(_cachedProfileKey);
    }
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final Map<String, dynamic> decoded =
          jsonDecode(raw) as Map<String, dynamic>;
      return UserProfileModel.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    try {
      await _secureStorage.delete(key: _jwtKey);
      await _secureStorage.delete(key: _userIdKey);
      await _secureStorage.delete(key: _cachedProfileKey);
    } catch (_) {}
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_jwtKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_cachedProfileKey);
  }

  Future<String> _resolveActiveUserId([String? explicitUserId]) async {
    if (explicitUserId != null && explicitUserId.trim().isNotEmpty) {
      return explicitUserId.trim();
    }
    final String? stored = await readUserId();
    if (stored != null && stored.trim().isNotEmpty) {
      return stored.trim();
    }
    final UserProfileModel? profile = await readUserProfileCache();
    if (profile != null && profile.id.trim().isNotEmpty) {
      return profile.id.trim();
    }
    return 'anonymous';
  }

  Future<void> saveHydrationLogsForDate(
    String ymd,
    List<Map<String, dynamic>> logs, {
    String? userId,
  }) async {
    final String uid = await _resolveActiveUserId(userId);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_hydrationLogsPrefix${uid}_$ymd', jsonEncode(logs));
  }

  Future<List<Map<String, dynamic>>> readHydrationLogsForDate(
    String ymd, {
    String? userId,
  }) async {
    final String uid = await _resolveActiveUserId(userId);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('$_hydrationLogsPrefix${uid}_$ymd');
    if (raw == null || raw.isEmpty) {
      return <Map<String, dynamic>>[];
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> saveUnitSystem(String unit) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_unitKey, unit == 'LB' ? 'LB' : 'KG');
  }

  Future<String> readUnitSystem() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_unitKey) ?? 'KG';
  }

  Future<void> savePreferredWearable(String source) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_wearableKey, source);
  }

  Future<String> readPreferredWearable() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_wearableKey) ?? 'WHOOP';
  }

  Future<void> saveApiBaseUrl(String url) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiBaseUrlKey, url.trim());
  }

  Future<String?> readApiBaseUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString(_apiBaseUrlKey);
    if (saved == null || saved.trim().isEmpty) {
      return null;
    }
    return saved.trim();
  }

  /// Guarda la periodización completa de 5 días indexada estrictamente por `user_routine_${currentUser.id}`.
  Future<void> saveCachedAiRoutinePlan(
    AiGeneratedRoutinePlanModel plan, {
    String? userId,
  }) async {
    final String uid = await _resolveActiveUserId(userId);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_userRoutinePrefix$uid',
      jsonEncode(plan.toJson()),
    );
    if (plan.days.isNotEmpty) {
      await saveCachedRoutineTemplates(plan.days, userId: uid);
    }
  }

  /// Lee la rutina de 5 días aislada por usuario (`user_routine_${currentUser.id}`).
  Future<AiGeneratedRoutinePlanModel?> readCachedAiRoutinePlan({
    String? userId,
  }) async {
    final String uid = await _resolveActiveUserId(userId);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('$_userRoutinePrefix$uid');
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final Map<String, dynamic> decoded =
          jsonDecode(raw) as Map<String, dynamic>;
      return AiGeneratedRoutinePlanModel.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCachedRoutineTemplates(
    List<RoutineTemplateModel> routines, {
    String? userId,
  }) async {
    final String uid = await _resolveActiveUserId(userId);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> encodedList =
        routines.map((RoutineTemplateModel r) => r.toJson()).toList();
    await prefs.setString(
      '$_userRoutineTemplatesPrefix$uid',
      jsonEncode(encodedList),
    );
  }

  Future<List<RoutineTemplateModel>> readCachedRoutineTemplates({
    String? userId,
  }) async {
    final String uid = await _resolveActiveUserId(userId);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('$_userRoutineTemplatesPrefix$uid');
    if (raw == null || raw.isEmpty) {
      return <RoutineTemplateModel>[];
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(RoutineTemplateModel.fromJson)
          .toList();
    } catch (_) {
      return <RoutineTemplateModel>[];
    }
  }

  /// Persiste localmente la telemetría de wearable aislada por usuario (`user_wearable_${currentUser.id}`).
  Future<void> saveCachedWearableTelemetry(
    WearableMetricRecord record, {
    String? userId,
  }) async {
    final String uid = await _resolveActiveUserId(userId);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> payload = <String, dynamic>{
      'date': record.date.toIso8601String(),
      'strain_score': record.strainScore,
      'recovery_score': record.recoveryScore,
      'hrv_ms': record.hrvMs,
      'resting_hr': record.restingHr,
      'avg_hr': record.avgHr,
      'max_hr': record.maxHr,
      'sleep_hours': record.sleepHours,
      'sleep_efficiency_pct': record.sleepEfficiencyPct,
      'sleep_pct': record.sleepEfficiencyPct,
      'source_device': record.sourceDevice,
      'whoop_stress_level': record.whoopStressLevel,
      'stress_level': record.whoopStressLevel,
      'whoop_health_metrics_in_range': record.whoopHealthMetricsInRange,
      'huawei_stress_score': record.huaweiStressScore,
      'huawei_trusleep_score': record.huaweiTruSleepScore,
      'huawei_vo2_max': record.huaweiVo2Max,
      'samsung_energy_score': record.samsungEnergyScore,
      'samsung_bia_muscle_pct': record.samsungBiaMusclePct,
      'samsung_bia_fat_pct': record.samsungBiaFatPct,
      'apple_move_kcal': record.appleMoveKcal,
      'apple_exercise_minutes': record.appleExerciseMinutes,
      'apple_stand_hours': record.appleStandHours,
    };
    await prefs.setString('$_userWearablePrefix$uid', jsonEncode(payload));
  }

  /// Lee la telemetría de wearable aislada por usuario (`user_wearable_${currentUser.id}`).
  Future<WearableMetricRecord> readCachedWearableTelemetry({
    String defaultSource = 'WHOOP',
    String? userId,
  }) async {
    final String uid = await _resolveActiveUserId(userId);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('$_userWearablePrefix$uid');
    if (raw != null && raw.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded =
            jsonDecode(raw) as Map<String, dynamic>;
        final WearableMetricRecord parsed =
            WearableMetricRecord.fromJson(decoded);
        if (!(parsed.recoveryScore.round() == 62 &&
            parsed.sleepEfficiencyPct.round() == 90)) {
          return parsed;
        }
      } catch (_) {}
    }

    final WearableMetricRecord initial = WearableMetricRecord(
      date: DateTime.now(),
      strainScore: 7.4,
      recoveryScore: 47.0,
      hrvMs: 56.0,
      restingHr: 58,
      avgHr: 68,
      maxHr: 155,
      sleepHours: 7.7,
      sleepEfficiencyPct: 80.0,
      sourceDevice: defaultSource,
      whoopStressLevel: 1.8,
      whoopHealthMetricsInRange: 5,
    );
    await saveCachedWearableTelemetry(initial, userId: uid);
    return initial;
  }

  Future<void> saveCachedBiometrics(
    BiometricRecord record, {
    String? userId,
  }) async {
    final String uid = await _resolveActiveUserId(userId);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_userBiometricsPrefix$uid',
      jsonEncode(record.toJson()),
    );
  }

  Future<BiometricRecord?> readCachedBiometrics({
    String? userId,
  }) async {
    final String uid = await _resolveActiveUserId(userId);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('$_userBiometricsPrefix$uid');
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final Map<String, dynamic> decoded =
          jsonDecode(raw) as Map<String, dynamic>;
      return BiometricRecord.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Guarda el dispositivo Bluetooth BLE emparejado (`last_paired_ble_id_${currentUser.id}` y `last_paired_ble_name_${currentUser.id}`)
  /// para reconexión automática Zero-Touch en segundo plano.
  Future<void> savePairedBleDevice({
    required String deviceId,
    required String deviceName,
    String? userId,
  }) async {
    final String uid = await _resolveActiveUserId(userId);
    final String idKey = '$_pairedBleIdPrefix$uid';
    final String nameKey = '$_pairedBleNamePrefix$uid';
    try {
      await _secureStorage.write(key: idKey, value: deviceId);
      await _secureStorage.write(key: nameKey, value: deviceName);
      await _secureStorage.write(key: _globalPairedBleIdKey, value: deviceId);
      await _secureStorage.write(
        key: _globalPairedBleNameKey,
        value: deviceName,
      );
    } catch (_) {}
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(idKey, deviceId);
    await prefs.setString(nameKey, deviceName);
    await prefs.setString(_globalPairedBleIdKey, deviceId);
    await prefs.setString(_globalPairedBleNameKey, deviceName);
  }

  /// Lee el último dispositivo BLE emparejado para el usuario activo.
  Future<({String id, String name})?> readPairedBleDevice({
    String? userId,
  }) async {
    final String uid = await _resolveActiveUserId(userId);
    final String idKey = '$_pairedBleIdPrefix$uid';
    final String nameKey = '$_pairedBleNamePrefix$uid';

    String? savedId;
    String? savedName;
    try {
      savedId = await _secureStorage.read(key: idKey);
      savedName = await _secureStorage.read(key: nameKey);
    } catch (_) {}

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (savedId == null || savedId.trim().isEmpty) {
      savedId = prefs.getString(idKey);
      savedName = prefs.getString(nameKey);
    }
    if (savedId == null || savedId.trim().isEmpty) {
      try {
        savedId = await _secureStorage.read(key: _globalPairedBleIdKey);
        savedName = await _secureStorage.read(key: _globalPairedBleNameKey);
      } catch (_) {}
    }
    if (savedId == null || savedId.trim().isEmpty) {
      savedId = prefs.getString(_globalPairedBleIdKey);
      savedName = prefs.getString(_globalPairedBleNameKey);
    }
    if (savedId == null || savedId.trim().isEmpty) {
      return null;
    }
    final String cleanName =
        (savedName != null && savedName.trim().isNotEmpty)
            ? savedName.trim()
            : 'Wearable BLE';
    return (id: savedId.trim(), name: cleanName);
  }

  /// Borra el dispositivo BLE emparejado cuando el usuario pulsa explícitamente "Olvidar / Desvincular".
  Future<void> clearPairedBleDevice({String? userId}) async {
    final String uid = await _resolveActiveUserId(userId);
    final String idKey = '$_pairedBleIdPrefix$uid';
    final String nameKey = '$_pairedBleNamePrefix$uid';
    try {
      await _secureStorage.delete(key: idKey);
      await _secureStorage.delete(key: nameKey);
      await _secureStorage.delete(key: _globalPairedBleIdKey);
      await _secureStorage.delete(key: _globalPairedBleNameKey);
    } catch (_) {}
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(idKey);
    await prefs.remove(nameKey);
    await prefs.remove(_globalPairedBleIdKey);
    await prefs.remove(_globalPairedBleNameKey);
  }
}
