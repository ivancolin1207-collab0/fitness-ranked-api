import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/auth_models.dart';
import '../../data/services/secure_storage_service.dart';

/// Servicio central de persistencia de sesión (Auto-Login definitivo).
/// Garantiza que `jwt_token` y `user_id` permanezcan almacenados en
/// `FlutterSecureStorage` (con respaldo en `SharedPreferences`) y nunca se
/// eliminen a menos que el atleta pulse explícitamente "Cerrar sesión".
class AuthService {
  static const String jwtTokenKey = 'jwt_token';
  static const String userIdKey = 'user_id';

  final SecureStorageService _storageService;
  final FlutterSecureStorage _secureStorage;

  const AuthService({
    SecureStorageService? storageService,
    FlutterSecureStorage? secureStorage,
  })  : _storageService = storageService ?? const SecureStorageService(),
        _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
                resetOnError: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  /// Guarda de forma atómica el `jwt_token` y `user_id` tras login o registro.
  Future<void> persistSession({
    required String jwtToken,
    required String userId,
    UserProfileModel? profile,
  }) async {
    await _storageService.saveJwtToken(jwtToken);
    await _storageService.saveUserId(userId);
    try {
      await _secureStorage.write(key: jwtTokenKey, value: jwtToken);
      await _secureStorage.write(key: userIdKey, value: userId);
    } catch (_) {}
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(jwtTokenKey, jwtToken);
    await prefs.setString(userIdKey, userId);

    if (profile != null) {
      await _storageService.saveUserProfileCache(profile);
    }
  }

  /// Obtiene el token JWT activo desde almacenamiento seguro.
  Future<String?> readActiveJwtToken() async {
    final String? primary = await _storageService.readJwtToken();
    if (primary != null && primary.isNotEmpty) {
      return primary;
    }
    try {
      final String? alt = await _secureStorage.read(key: jwtTokenKey);
      if (alt != null && alt.isNotEmpty) {
        await _storageService.saveJwtToken(alt);
        return alt;
      }
    } catch (_) {}
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? prefToken = prefs.getString(jwtTokenKey);
    if (prefToken != null && prefToken.isNotEmpty) {
      await _storageService.saveJwtToken(prefToken);
      return prefToken;
    }
    return null;
  }

  /// Obtiene el `user_id` persistido.
  Future<String?> readActiveUserId() async {
    final String? primary = await _storageService.readUserId();
    if (primary != null && primary.isNotEmpty) {
      return primary;
    }
    try {
      final String? alt = await _secureStorage.read(key: userIdKey);
      if (alt != null && alt.isNotEmpty) {
        return alt;
      }
    } catch (_) {}
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(userIdKey);
  }

  /// Verifica al arrancar la app si existe sesión persistida válida.
  Future<bool> hasPersistedSession() async {
    final String? token = await readActiveJwtToken();
    return token != null && token.trim().isNotEmpty;
  }

  /// Cierra sesión únicamente cuando el usuario lo solicita de forma explícita.
  Future<void> logoutExplicitly() async {
    await _storageService.clearSession();
    try {
      await _secureStorage.delete(key: jwtTokenKey);
      await _secureStorage.delete(key: userIdKey);
    } catch (_) {}
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(jwtTokenKey);
    await prefs.remove(userIdKey);
  }
}
