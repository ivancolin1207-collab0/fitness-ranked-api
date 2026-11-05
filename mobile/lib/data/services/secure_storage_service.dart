import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_models.dart';

class SecureStorageService {
  static const String _jwtKey = 'apexmetrix_jwt_token';
  static const String _userIdKey = 'apexmetrix_user_id';
  static const String _cachedProfileKey = 'apexmetrix_cached_user_profile_v1';
  static const String _unitKey = 'apexmetrix_unit_system';
  static const String _wearableKey = 'apexmetrix_preferred_wearable';
  static const String _apiBaseUrlKey = 'apexmetrix_cloud_api_url_v2';
  static const String _hydrationLogsPrefix = 'apexmetrix_hydration_logs_';

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

  Future<void> saveHydrationLogsForDate(
    String ymd,
    List<Map<String, dynamic>> logs,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_hydrationLogsPrefix$ymd', jsonEncode(logs));
  }

  Future<List<Map<String, dynamic>>> readHydrationLogsForDate(
    String ymd,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('$_hydrationLogsPrefix$ymd');
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
}
