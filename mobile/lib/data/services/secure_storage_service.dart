import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static const String _jwtKey = 'apexmetrix_jwt_token';
  static const String _unitKey = 'apexmetrix_unit_system';
  static const String _wearableKey = 'apexmetrix_preferred_wearable';
  static const String _apiBaseUrlKey = 'apexmetrix_cloud_api_url_v2';

  final FlutterSecureStorage _secureStorage;

  const SecureStorageService({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  Future<void> saveJwtToken(String token) async {
    await _secureStorage.write(key: _jwtKey, value: token);
  }

  Future<String?> readJwtToken() async {
    return _secureStorage.read(key: _jwtKey);
  }

  Future<void> clearSession() async {
    await _secureStorage.delete(key: _jwtKey);
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
