import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../data/services/secure_storage_service.dart';
import '../constants/api_constants.dart';
import '../network/api_client.dart';
import 'auth_service.dart';

class WearableScanException implements Exception {
  final int statusCode;
  final String message;

  const WearableScanException({
    required this.statusCode,
    required this.message,
  });

  @override
  String toString() =>
      statusCode > 0 ? 'HTTP $statusCode: $message' : message;
}

class WhoopOAuthStatusModel {
  final bool oauthConfigured;
  final bool linked;
  final String? authorizeUrl;
  final String? updatedAt;

  const WhoopOAuthStatusModel({
    required this.oauthConfigured,
    required this.linked,
    this.authorizeUrl,
    this.updatedAt,
  });

  factory WhoopOAuthStatusModel.fromJson(Map<String, dynamic> json) {
    return WhoopOAuthStatusModel(
      oauthConfigured: json['oauth_configured'] == true,
      linked: json['linked'] == true,
      authorizeUrl: json['authorize_url'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }
}

/// Servicio dedicado para el escaneo de capturas de WHOOP / Wearables con Gemini Vision
/// y sincronización oficial WHOOP Cloud OAuth 2.0 (`api.prod.whoop.com`).
class WearableService {
  final http.Client _httpClient;
  final SecureStorageService _storageService;
  final AuthService _authService;
  static const MethodChannel _systemChannel =
      MethodChannel('apexmetrix/system');

  WearableService({
    http.Client? httpClient,
    SecureStorageService? storageService,
    AuthService? authService,
  })  : _httpClient = httpClient ?? http.Client(),
        _storageService = storageService ?? const SecureStorageService(),
        _authService = authService ?? const AuthService();

  String _normalizeBaseUrl(String? rawUrl) {
    final String candidate = (rawUrl != null && rawUrl.trim().isNotEmpty)
        ? rawUrl.trim()
        : ApiConstants.defaultProductionBaseUrl;
    final String low = candidate.toLowerCase();
    if (low.contains('192.168.') ||
        low.contains('10.0.2.2') ||
        low.contains('127.0.0.1') ||
        low.contains('localhost')) {
      return ApiConstants.defaultProductionBaseUrl;
    }
    return candidate
        .replaceAll(RegExp(r'/+$'), '')
        .replaceAll(RegExp(r'/api/v1$'), '');
  }

  Future<String> _resolveTargetBaseUrl(String? explicitBaseUrl) async {
    if (explicitBaseUrl != null && explicitBaseUrl.trim().isNotEmpty) {
      return _normalizeBaseUrl(explicitBaseUrl);
    }
    final String? savedUrl = await _storageService.readApiBaseUrl();
    return _normalizeBaseUrl(savedUrl);
  }

  Future<String?> _resolveJwtToken(String? explicitToken) async {
    if (explicitToken != null && explicitToken.trim().isNotEmpty) {
      return explicitToken.trim();
    }
    final String? active = await _authService.readActiveJwtToken();
    if (active != null && active.trim().isNotEmpty) {
      return active.trim();
    }
    return _storageService.readJwtToken();
  }

  /// Abre una URL externa en el navegador del sistema (para OAuth 2.0 WHOOP Cloud).
  Future<bool> openExternalBrowserUrl(String url) async {
    try {
      final bool? ok = await _systemChannel.invokeMethod<bool>(
        'openExternalUrl',
        <String, dynamic>{'url': url},
      );
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  /// Abre la pantalla nativa de permisos de Health Connect en Android 14/15/16.
  Future<bool> openHealthConnectSettings() async {
    try {
      final bool? ok = await _systemChannel.invokeMethod<bool>(
        'openHealthConnectSettings',
      );
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  /// Consulta el estado de vinculación OAuth 2.0 con WHOOP Cloud (`GET /api/v1/wearables/whoop/oauth/status`).
  Future<WhoopOAuthStatusModel?> fetchWhoopOAuthStatus({
    String? baseUrl,
    String? jwtToken,
  }) async {
    try {
      final String targetBase = await _resolveTargetBaseUrl(baseUrl);
      final String? token = await _resolveJwtToken(jwtToken);
      if (token == null || token.isEmpty) {
        return null;
      }
      final http.Response res = await _httpClient
          .get(
            Uri.parse('$targetBase/api/v1/wearables/whoop/oauth/status'),
            headers: <String, String>{
              HttpHeaders.acceptHeader: 'application/json',
              HttpHeaders.authorizationHeader: 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final Map<String, dynamic> decoded =
            jsonDecode(res.body) as Map<String, dynamic>;
        return WhoopOAuthStatusModel.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }

  /// Sincroniza directamente desde WHOOP Cloud API (`POST /api/v1/wearables/whoop/cloud-sync`).
  Future<Map<String, dynamic>> syncWhoopCloudNow({
    String? baseUrl,
    String? jwtToken,
  }) async {
    final String targetBase = await _resolveTargetBaseUrl(baseUrl);
    final String? token = await _resolveJwtToken(jwtToken);
    if (token == null || token.isEmpty) {
      throw const WearableScanException(
        statusCode: 401,
        message: 'Sesión no autenticada. Inicia sesión nuevamente.',
      );
    }
    final http.Response res = await _httpClient
        .post(
          Uri.parse('$targetBase/api/v1/wearables/whoop/cloud-sync'),
          headers: <String, String>{
            HttpHeaders.acceptHeader: 'application/json',
            HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
            HttpHeaders.authorizationHeader: 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw WearableScanException(
      statusCode: res.statusCode,
      message: ApiErrorSanitizer.sanitizeResponseError(res),
    );
  }

  /// Envía la captura comprimida de WHOOP/Wearable a FastAPI:
  /// 1. Intenta primero `POST /api/v1/wearables/scan-whoop-base64` (JSON puro, inmune a errores 422 de Multipart).
  /// 2. Si el servidor devuelve 404, hace fallback automático a `MultipartRequest` en `/api/v1/wearables/scan-whoop`
  ///    y `/api/v1/wearables/scan-screen` enviando el campo `'file'`.
  /// 3. Si ocurre cualquier error HTTP o de red, lanza `WearableScanException` con el código exacto.
  Future<Map<String, dynamic>> scanWhoopScreenshot(
    Uint8List bytes, {
    String? baseUrl,
    String? jwtToken,
    String sourceDevice = 'WHOOP',
  }) async {
    if (bytes.isEmpty) {
      throw const WearableScanException(
        statusCode: 400,
        message: 'El archivo de imagen seleccionado está vacío.',
      );
    }

    final String targetBase = await _resolveTargetBaseUrl(baseUrl);
    final String? token = await _resolveJwtToken(jwtToken);

    final Map<String, String> jsonHeaders = <String, String>{
      HttpHeaders.acceptHeader: 'application/json',
      HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
      if (token != null && token.isNotEmpty)
        HttpHeaders.authorizationHeader: 'Bearer $token',
    };

    // 1. Intento primario por JSON Base64 (/api/v1/wearables/scan-whoop-base64)
    try {
      final Uri base64Uri =
          Uri.parse('$targetBase/api/v1/wearables/scan-whoop-base64');
      final String bodyJson = jsonEncode(<String, dynamic>{
        'image_base64': base64Encode(bytes),
        'mime_type': 'image/jpeg',
        'source_device': sourceDevice,
        'source_wearable': sourceDevice,
      });

      http.Response jsonRes = await _httpClient
          .post(base64Uri, headers: jsonHeaders, body: bodyJson)
          .timeout(ApiConstants.ocrUploadTimeout);

      int retryAttempt = 0;
      while ((jsonRes.statusCode == 502 ||
              jsonRes.statusCode == 503 ||
              jsonRes.statusCode == 504) &&
          retryAttempt < 3) {
        retryAttempt++;
        await Future<void>.delayed(Duration(seconds: retryAttempt * 2));
        jsonRes = await _httpClient
            .post(base64Uri, headers: jsonHeaders, body: bodyJson)
            .timeout(ApiConstants.ocrUploadTimeout);
      }

      if (jsonRes.statusCode == 200 || jsonRes.statusCode == 201) {
        return jsonDecode(jsonRes.body) as Map<String, dynamic>;
      }
      if (jsonRes.statusCode != 404 && jsonRes.statusCode != 405) {
        throw WearableScanException(
          statusCode: jsonRes.statusCode,
          message: ApiErrorSanitizer.sanitizeResponseError(jsonRes),
        );
      }
    } on WearableScanException {
      rethrow;
    } on TimeoutException {
      throw const WearableScanException(
        statusCode: 504,
        message:
            'Tiempo de espera agotado (90s) al analizar la captura con Gemini Vision en Render. Intenta de nuevo.',
      );
    } on SocketException catch (e) {
      throw WearableScanException(
        statusCode: 503,
        message:
            'Sin conexión de red con el servidor ($targetBase): ${e.message}',
      );
    } catch (_) {
      // Continuar al fallback Multipart si el endpoint Base64 devolvió 404/405
    }

    // 2. Fallback Multipart (/api/v1/wearables/scan-whoop y /api/v1/wearables/scan-screen)
    final List<String> paths = <String>[
      '/api/v1/wearables/scan-whoop',
      '/api/v1/wearables/scan-screen',
    ];

    http.Response? lastResponse;
    try {
      for (final String path in paths) {
        final Uri uri = Uri.parse('$targetBase$path');
        final http.MultipartRequest request = http.MultipartRequest('POST', uri);
        request.headers['Accept'] = 'application/json';
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }
        request.fields['source_device'] = sourceDevice;
        request.fields['source_wearable'] = sourceDevice;

        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: 'whoop_scan.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );

        final http.StreamedResponse streamed = await _httpClient
            .send(request)
            .timeout(ApiConstants.ocrUploadTimeout);
        final http.Response response = await http.Response.fromStream(streamed);
        lastResponse = response;

        if (response.statusCode == 200 || response.statusCode == 201) {
          final Map<String, dynamic> decoded =
              jsonDecode(response.body) as Map<String, dynamic>;
          return decoded;
        }
        if (response.statusCode != 404) {
          throw WearableScanException(
            statusCode: response.statusCode,
            message: ApiErrorSanitizer.sanitizeResponseError(response),
          );
        }
      }
    } on WearableScanException {
      rethrow;
    } on TimeoutException {
      throw const WearableScanException(
        statusCode: 504,
        message:
            'Tiempo de espera agotado (60s) al analizar la captura con Gemini Vision en Render.',
      );
    } on SocketException catch (e) {
      throw WearableScanException(
        statusCode: 503,
        message: 'Sin conexión de red con el servidor ($targetBase): ${e.message}',
      );
    } catch (e) {
      throw WearableScanException(
        statusCode: 500,
        message: 'Error inesperado al procesar la captura: $e',
      );
    }

    if (lastResponse != null) {
      throw WearableScanException(
        statusCode: lastResponse.statusCode,
        message: ApiErrorSanitizer.sanitizeResponseError(lastResponse),
      );
    }

    throw const WearableScanException(
      statusCode: 500,
      message: 'No se recibió respuesta del servidor de telemetría.',
    );
  }
}
