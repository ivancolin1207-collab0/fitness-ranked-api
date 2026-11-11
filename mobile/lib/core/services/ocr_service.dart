import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../data/models/biometric_models.dart';
import '../network/api_client.dart';

/// Servicio de OCR Biométrico Real con Gemini 2.5 Flash Vision (Fitdays & Wearables).
/// PROHIBIDO el retorno de diccionarios de prueba o valores quemados: si el escaneo
/// falla o el backend retorna error HTTP, propaga la excepción real para depuración.
class OcrService {
  const OcrService();

  /// Lee y valida los bytes del archivo JPEG comprimido antes de enviarlo.
  Future<Uint8List> prepareJpegPayload(File imageFile) async {
    if (!await imageFile.exists()) {
      throw const HttpException('El archivo de imagen seleccionado no existe.');
    }
    final bytes = await imageFile.readAsBytes();
    if (bytes.isEmpty) {
      throw const HttpException(
        'El archivo de imagen seleccionado está vacío.',
      );
    }
    return bytes;
  }

  String _extractErrorMessage(http.Response response) {
    return ApiErrorSanitizer.sanitizeResponseError(response);
  }

  /// Despacha el reporte Fitdays (`POST /api/v1/biometrics/scan`) con `contentType: MediaType('image', 'jpeg')`.
  /// Propaga el error real si falla (cero valores mock).
  Future<FitdaysExtractedMetricsModel> scanFitdaysReport({
    required File imageFile,
    required Uri endpointUri,
    required String? accessToken,
    required http.Client httpClient,
  }) async {
    final jpegBytes = await prepareJpegPayload(imageFile);

    final request = http.MultipartRequest('POST', endpointUri);
    request.headers['Accept'] = 'application/json';
    if (accessToken != null && accessToken.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        jpegBytes,
        filename: 'fitdays_scan.jpg',
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    final streamed = await httpClient.send(request).timeout(
          const Duration(seconds: 40),
        );
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
      return FitdaysExtractedMetricsModel.fromJson(jsonMap);
    }

    throw HttpException(_extractErrorMessage(response));
  }

  /// Envía los bytes JPEG de la captura de WHOOP a `/api/v1/wearables/scan-whoop`
  /// (con respaldo de ruta a `/api/v1/wearables/scan-screen`) y retorna el JSON real.
  Future<Map<String, dynamic>> scanWhoopScreenshotBytes({
    required Uint8List jpegBytes,
    required String baseUrl,
    required String? accessToken,
    required http.Client httpClient,
    String sourceDevice = 'WHOOP',
  }) async {
    if (jpegBytes.isEmpty) {
      throw const HttpException('La imagen seleccionada está vacía.');
    }

    final List<String> paths = <String>[
      '/api/v1/wearables/scan-whoop',
      '/api/v1/wearables/scan-screen',
    ];

    http.Response? lastResponse;
    for (final String path in paths) {
      final Uri uri = Uri.parse('$baseUrl$path');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Accept'] = 'application/json';
      if (accessToken != null && accessToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $accessToken';
      }
      request.fields['source_device'] = sourceDevice;
      request.fields['source_wearable'] = sourceDevice;

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          jpegBytes,
          filename: 'whoop_screen.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final streamed = await httpClient.send(request).timeout(
            const Duration(seconds: 40),
          );
      final response = await http.Response.fromStream(streamed);
      lastResponse = response;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode != 404) {
        throw HttpException(_extractErrorMessage(response));
      }
    }

    throw HttpException(
      lastResponse != null
          ? _extractErrorMessage(lastResponse)
          : 'No se pudo conectar con el endpoint de escaneo de WHOOP.',
    );
  }

  /// Escanea una captura de pantalla del wearable seleccionado (`POST /api/v1/wearables/scan-whoop`)
  /// enviando `source_device` y `source_wearable` junto con el archivo JPEG.
  Future<WearableMetricRecord> scanWhoopScreenReport({
    required File imageFile,
    required Uri endpointUri,
    required String? accessToken,
    required http.Client httpClient,
    String sourceDevice = 'WHOOP',
  }) async {
    final jpegBytes = await prepareJpegPayload(imageFile);
    final String baseUrl =
        '${endpointUri.scheme}://${endpointUri.host}${endpointUri.hasPort ? ":${endpointUri.port}" : ""}';

    final Map<String, dynamic> rawResult = await scanWhoopScreenshotBytes(
      jpegBytes: jpegBytes,
      baseUrl: baseUrl,
      accessToken: accessToken,
      httpClient: httpClient,
      sourceDevice: sourceDevice,
    );
    final Map<String, dynamic> result = rawResult['data'] is Map<String, dynamic>
        ? rawResult['data'] as Map<String, dynamic>
        : rawResult;

    final double recovery = ((result['recovery_score'] ?? 0.0) as num).toDouble();
    final double strain = ((result['strain_score'] ?? 0.0) as num).toDouble();
    final double sleep =
        ((result['sleep_pct'] ?? result['sleep_performance_pct'] ?? 0.0) as num)
            .toDouble();
    final double stress = ((result['stress_level'] ??
                result['whoop_stress_level'] ??
                0.0) as num)
        .toDouble();
    final double sleepHours = (result['sleep_hours'] as num?)?.toDouble() ??
        double.parse(((sleep / 100.0) * 8.0).toStringAsFixed(1));

    return WearableMetricRecord.fromJson(result).copyWith(
      recoveryScore: recovery,
      strainScore: strain,
      sleepEfficiencyPct: sleep,
      sleepHours: sleepHours,
      whoopStressLevel: stress,
      sourceDevice: sourceDevice,
    );
  }
}
