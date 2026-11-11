import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_models.dart';
import '../models/biometric_models.dart';
import '../models/workout_models.dart';

class SecureStorageService {
  static const String _jwtKey = 'apexmetrix_jwt_token';
  static const String _userIdKey = 'apexmetrix_user_id';
  static const String _cachedProfileKey = 'apexmetrix_cached_user_profile_v2';
  static const String _unitPrefix = 'unit_';
  static const String _wearablePrefPrefix = 'wearable_pref_';
  static const String _apiBaseUrlKey = 'apexmetrix_cloud_api_url_v2';
  static const String _hydrationLogsPrefix = 'hydration_';
  static const String _routinePrefix = 'routine_';
  static const String _routineTemplatesPrefix = 'routine_templates_';
  static const String _readinessPrefix = 'readiness_';
  static const String _biometricsPrefix = 'biometrics_';
  static const String _pairedBleIdPrefix = 'last_paired_ble_id_';
  static const String _pairedBleNamePrefix = 'last_paired_ble_name_';

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

  String _todayYmd() {
    final DateTime now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<String?> _tryResolveActiveUserId([String? explicitUserId]) async {
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
    return null;
  }

  Future<void> saveHydrationLogsForDate(
    String ymd,
    List<Map<String, dynamic>> logs, {
    String? userId,
  }) async {
    final String? uid = await _tryResolveActiveUserId(userId);
    if (uid == null) {
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_hydrationLogsPrefix${uid}_$ymd', jsonEncode(logs));
  }

  Future<List<Map<String, dynamic>>> readHydrationLogsForDate(
    String ymd, {
    String? userId,
  }) async {
    final String? uid = await _tryResolveActiveUserId(userId);
    if (uid == null) {
      return <Map<String, dynamic>>[];
    }
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

  Future<void> saveUnitSystem(String unit, {String? userId}) async {
    final String? uid = await _tryResolveActiveUserId(userId);
    if (uid == null) {
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_unitPrefix$uid', unit == 'LB' ? 'LB' : 'KG');
  }

  Future<String> readUnitSystem({String? userId}) async {
    final String? uid = await _tryResolveActiveUserId(userId);
    if (uid == null) {
      return 'KG';
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_unitPrefix$uid') ?? 'KG';
  }

  Future<void> savePreferredWearable(String source, {String? userId}) async {
    final String? uid = await _tryResolveActiveUserId(userId);
    if (uid == null) {
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_wearablePrefPrefix$uid', source);
  }

  Future<String> readPreferredWearable({String? userId}) async {
    final String? uid = await _tryResolveActiveUserId(userId);
    if (uid == null) {
      return 'WHOOP';
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_wearablePrefPrefix$uid') ?? 'WHOOP';
  }

  bool _isStaleLocalUrl(String url) {
    final String low = url.toLowerCase().trim();
    return low.contains('192.168.') ||
        low.contains('10.0.2.2') ||
        low.contains('127.0.0.1') ||
        low.contains('localhost');
  }

  Future<void> saveApiBaseUrl(String url) async {
    final String cleaned = url.trim();
    if (_isStaleLocalUrl(cleaned)) {
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiBaseUrlKey, cleaned);
  }

  Future<String?> readApiBaseUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString(_apiBaseUrlKey);
    if (saved == null || saved.trim().isEmpty) {
      return null;
    }
    final String cleaned = saved.trim();
    if (_isStaleLocalUrl(cleaned)) {
      await prefs.remove(_apiBaseUrlKey);
      return null;
    }
    return cleaned;
  }

  /// Guarda la periodización completa de 5 días indexada estrictamente por `routine_${userId}`.
  Future<void> saveCachedAiRoutinePlan(
    AiGeneratedRoutinePlanModel plan, {
    String? userId,
  }) async {
    final String? uid = await _tryResolveActiveUserId(userId);
    if (uid == null) {
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_routinePrefix$uid',
      jsonEncode(plan.toJson()),
    );
    if (plan.days.isNotEmpty) {
      await saveCachedRoutineTemplates(plan.days, userId: uid);
    }
  }

  /// Lee la rutina de 5 días aislada por usuario (`routine_${userId}`).
  Future<AiGeneratedRoutinePlanModel?> readCachedAiRoutinePlan({
    String? userId,
  }) async {
    final String? uid = await _tryResolveActiveUserId(userId);
    if (uid == null) {
      return null;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('$_routinePrefix$uid');
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

  /// Invalida la rutina cacheada localmente del usuario (`routine_${userId}`).
  Future<void> clearCachedAiRoutinePlan({String? userId}) async {
    final String? uid = await _tryResolveActiveUserId(userId);
    if (uid == null) {
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_routinePrefix$uid');
    await prefs.remove('$_routineTemplatesPrefix$uid');
  }

  Future<void> saveCachedRoutineTemplates(
    List<RoutineTemplateModel> routines, {
    String? userId,
  }) async {
    final String? uid = await _tryResolveActiveUserId(userId);
    if (uid == null) {
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> encodedList =
        routines.map((RoutineTemplateModel r) => r.toJson()).toList();
    await prefs.setString(
      '$_routineTemplatesPrefix$uid',
      jsonEncode(encodedList),
    );
  }

  Future<List<RoutineTemplateModel>> readCachedRoutineTemplates({
    String? userId,
  }) async {
    final String? uid = await _tryResolveActiveUserId(userId);
    if (uid == null) {
      return <RoutineTemplateModel>[];
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('$_routineTemplatesPrefix$uid');
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

  /// Persiste localmente la telemetría de hoy aislada por usuario (`readiness_${userId}_${today}`).
  Future<void> saveCachedWearableTelemetry(
    WearableMetricRecord record, {
    String? userId,
  }) async {
    final String? uid = await _tryResolveActiveUserId(userId);
    if (uid == null) {
      return;
    }
    final String ymd = _todayYmd();
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
      if (record.stressCategory != null) 'stress_category': record.stressCategory,
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
    await prefs.setString('$_readinessPrefix${uid}_$ymd', jsonEncode(payload));
  }

  /// Lee la telemetría de hoy aislada por usuario (`readiness_${userId}_${today}`).
  /// Si el usuario aún no ha escaneado o sincronizado hoy, retorna `null` (cero mocks).
  Future<WearableMetricRecord?> readCachedWearableTelemetry({
    String defaultSource = 'WHOOP',
    String? userId,
  }) async {
    final String? uid = await _tryResolveActiveUserId(userId);
    if (uid == null) {
      return null;
    }
    final String ymd = _todayYmd();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('$_readinessPrefix${uid}_$ymd');
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final Map<String, dynamic> decoded =
          jsonDecode(raw) as Map<String, dynamic>;
      return WearableMetricRecord.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCachedWearableTelemetry({String? userId}) async {
    final String? uid = await _tryResolveActiveUserId(userId);
    if (uid == null) {
      return;
    }
    final String ymd = _todayYmd();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_readinessPrefix${uid}_$ymd');
  }

  Future<void> saveCachedBiometrics(
    BiometricRecord record, {
    String? userId,
  }) async {
    final String? uid = await _tryResolveActiveUserId(userId);
    if (uid == null) {
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_biometricsPrefix$uid',
      jsonEncode(record.toJson()),
    );
  }

  Future<BiometricRecord?> readCachedBiometrics({
    String? userId,
  }) async {
    final String? uid = await _tryResolveActiveUserId(userId);
    if (uid == null) {
      return null;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('$_biometricsPrefix$uid');
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

  /// Guarda el dispositivo Bluetooth BLE emparejado (`last_paired_ble_id_${userId}` y `last_paired_ble_name_${userId}`)
  /// estrictamente aislado por usuario.
  Future<void> savePairedBleDevice({
    required String deviceId,
    required String deviceName,
    String? userId,
  }) async {
    final String? uid = await _tryResolveActiveUserId(userId);
    if (uid == null) {
      return;
    }
    final String idKey = '$_pairedBleIdPrefix$uid';
    final String nameKey = '$_pairedBleNamePrefix$uid';
    try {
      await _secureStorage.write(key: idKey, value: deviceId);
      await _secureStorage.write(key: nameKey, value: deviceName);
    } catch (_) {}
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(idKey, deviceId);
    await prefs.setString(nameKey, deviceName);
  }

  /// Lee el último dispositivo BLE emparejado para el usuario activo.
  Future<({String id, String name})?> readPairedBleDevice({
    String? userId,
  }) async {
    final String? uid = await _tryResolveActiveUserId(userId);
    if (uid == null) {
      return null;
    }
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
    final String? uid = await _tryResolveActiveUserId(userId);
    if (uid == null) {
      return;
    }
    final String idKey = '$_pairedBleIdPrefix$uid';
    final String nameKey = '$_pairedBleNamePrefix$uid';
    try {
      await _secureStorage.delete(key: idKey);
      await _secureStorage.delete(key: nameKey);
    } catch (_) {}
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(idKey);
    await prefs.remove(nameKey);
  }
}
