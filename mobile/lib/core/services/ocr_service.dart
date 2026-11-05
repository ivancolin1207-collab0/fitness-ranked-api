import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../data/models/biometric_models.dart';

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
    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['detail'] != null) {
        return 'Error HTTP ${response.statusCode}: ${decoded['detail']}';
      }
    } catch (_) {}
    return 'Error HTTP ${response.statusCode}: ${response.body}';
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

  /// Escanea una captura de pantalla del wearable seleccionado (`POST /api/v1/wearables/scan-screen`)
  /// enviando `source_device` y `source_wearable` junto con el archivo JPEG.
  /// Propaga el error real si falla (cero valores mock).
  Future<WearableMetricRecord> scanWhoopScreenReport({
    required File imageFile,
    required Uri endpointUri,
    required String? accessToken,
    required http.Client httpClient,
    String sourceDevice = 'WHOOP',
  }) async {
    final jpegBytes = await prepareJpegPayload(imageFile);

    final request = http.MultipartRequest('POST', endpointUri);
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
        filename: 'wearable_screen.jpg',
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    final streamed = await httpClient.send(request).timeout(
          const Duration(seconds: 40),
        );
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final result = jsonDecode(response.body) as Map<String, dynamic>;
      final double recovery = (result['recovery_score'] as num).toDouble();
      final double strain = (result['strain_score'] as num).toDouble();
      final double sleep =
          ((result['sleep_pct'] ?? result['sleep_performance_pct']) as num)
              .toDouble();
      final double stress =
          ((result['stress_level'] ?? result['whoop_stress_level'] ?? 0.0)
                  as num)
              .toDouble();

      return WearableMetricRecord.fromJson(result).copyWith(
        recoveryScore: recovery,
        strainScore: strain,
        sleepEfficiencyPct: sleep,
        whoopStressLevel: stress,
        sourceDevice: sourceDevice,
      );
    }

    throw HttpException(_extractErrorMessage(response));
  }
}
