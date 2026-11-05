import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../data/models/biometric_models.dart';

/// Servicio dedicado de OCR Biométrico (Fitdays / InBody) con Gemini Vision.
/// Garantiza que cualquier archivo capturado o seleccionado desde la galería
/// (comprimido a JPEG calidad 90) sea despachado con MIME explícito `image/jpeg`
/// tanto en la cabecera Multipart HTTP como hacia Gemini Vision.
class OcrService {
  const OcrService();

  /// Lee y valida los bytes del archivo JPEG comprimido antes de enviarlo.
  Future<Uint8List> prepareJpegPayload(File imageFile) async {
    if (!await imageFile.exists()) {
      throw Exception('El archivo de imagen seleccionado no existe.');
    }
    final bytes = await imageFile.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('El archivo de imagen seleccionado está vacío.');
    }
    return bytes;
  }

  /// Despacha el reporte Fitdays con `contentType: MediaType('image', 'jpeg')`.
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
          const Duration(seconds: 35),
        );
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200 && response.statusCode != 201) {
      String detail = 'Error HTTP ${response.statusCode}';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['detail'] != null) {
          detail = decoded['detail'].toString();
        }
      } catch (_) {}
      throw Exception(detail);
    }

    final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
    return FitdaysExtractedMetricsModel.fromJson(jsonMap);
  }
}
