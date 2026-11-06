import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../data/services/secure_storage_service.dart';
import '../constants/api_constants.dart';
import '../network/api_client.dart';

class WearableScanException implements Exception {
  final int? statusCode;
  final String message;

  const WearableScanException({
    this.statusCode,
    required this.message,
  });

  @override
  String toString() {
    if (statusCode != null) {
      return 'HTTP $statusCode: $message';
    }
    return message;
  }
}

/// Servicio dedicado de sincronización y escaneo óptico de capturas de WHOOP (`POST /api/v1/wearables/scan-whoop`).
class WearableService {
  final SecureStorageService _storageService;
  final http.Client _httpClient;

  WearableService({
    SecureStorageService? storageService,
    http.Client? httpClient,
  })  : _storageService = storageService ?? const SecureStorageService(),
        _httpClient = httpClient ?? http.Client();

  String _extractDetail(http.Response response) {
    return ApiErrorSanitizer.sanitizeResponseError(response);
  }

  MediaType _detectMediaType(Uint8List bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return MediaType('image', 'png');
    }
    return MediaType('image', 'jpeg');
  }

  /// Envía la captura de pantalla de WHOOP a `POST https://fitness-ranked-api.onrender.com/api/v1/wearables/scan-whoop`
  /// (con respaldo a `/api/v1/wearables/scan-screen`) y retorna el diccionario JSON parseado por Gemini Vision.
  /// Si ocurre cualquier error HTTP o de red, lanza `WearableScanException` con el código de estado exacto.
  Future<Map<String, dynamic>> scanWhoopScreenshot(
    Uint8List bytes, {
    String? baseUrl,
    String? jwtToken,
    String sourceDevice = 'WHOOP',
  }) async {
    if (bytes.isEmpty) {
      throw const WearableScanException(
        statusCode: 400,
        message: 'La imagen seleccionada está vacía (0 bytes).',
      );
    }

    final String resolvedToken =
        jwtToken ?? (await _storageService.readJwtToken()) ?? '';
    final String targetBase = (baseUrl != null && baseUrl.trim().isNotEmpty)
        ? baseUrl.trim().replaceAll(RegExp(r'/+$'), '')
        : ApiConstants.defaultProductionBaseUrl;

    final List<String> paths = <String>[
      '/api/v1/wearables/scan-whoop',
      '/api/v1/wearables/scan-screen',
    ];

    final MediaType mediaType = _detectMediaType(bytes);
    final String ext = mediaType.subtype == 'png' ? 'png' : 'jpg';
    http.Response? lastResponse;

    for (final String path in paths) {
      final Uri uri = Uri.parse('$targetBase$path');
      final http.MultipartRequest request = http.MultipartRequest('POST', uri);
      request.headers['Accept'] = 'application/json';
      if (resolvedToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $resolvedToken';
      }
      request.fields['source_device'] = sourceDevice;
      request.fields['source_wearable'] = sourceDevice;

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'whoop_capture.$ext',
          contentType: mediaType,
        ),
      );

      try {
        final http.StreamedResponse streamed = await _httpClient
            .send(request)
            .timeout(const Duration(seconds: 45));
        final http.Response response =
            await http.Response.fromStream(streamed);
        lastResponse = response;

        if (response.statusCode == 200 || response.statusCode == 201) {
          final dynamic decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
          throw const WearableScanException(
            statusCode: 500,
            message: 'El servidor devolvió un formato JSON inesperado.',
          );
        }

        // Si el endpoint principal devuelve 404 (ej. despliegue en curso), probar ruta alternativa
        if (response.statusCode != 404) {
          throw WearableScanException(
            statusCode: response.statusCode,
            message: _extractDetail(response),
          );
        }
      } on WearableScanException {
        rethrow;
      } on SocketException catch (e) {
        throw WearableScanException(
          statusCode: 503,
          message: 'Error de red al conectar con Render: ${e.message}',
        );
      } catch (e) {
        throw WearableScanException(
          statusCode: lastResponse?.statusCode,
          message: e.toString().replaceFirst('HttpException: ', ''),
        );
      }
    }

    throw WearableScanException(
      statusCode: lastResponse?.statusCode ?? 404,
      message: lastResponse != null
          ? _extractDetail(lastResponse)
          : 'Endpoint /api/v1/wearables/scan-whoop no encontrado.',
    );
  }
}
