class ApiConstants {
  ApiConstants._();

  /// URL pública de producción en Render para operar 100% en la nube sin Mac local.
  static const String defaultProductionBaseUrl =
      'https://fitness-ranked-api.onrender.com';

  /// Timeout extendido (>= 30s) para tolerar el arranque en frío (cold start) de Render.
  static const Duration requestTimeout = Duration(seconds: 45);

  /// Timeout extendido para subida de capturas OCR Fitdays + procesamiento Gemini Vision.
  static const Duration ocrUploadTimeout = Duration(seconds: 60);
}
