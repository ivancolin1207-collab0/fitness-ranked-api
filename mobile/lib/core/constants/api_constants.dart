class ApiConstants {
  ApiConstants._();

  /// URL pública de producción en Render para operar 100% en la nube sin Mac local.
  static const String defaultProductionBaseUrl =
      'https://fitness-ranked-api.onrender.com';

  /// Fallbacks automáticos de desarrollo local cuando el Web Service de Render aún no está desplegado.
  static const String fallbackLocalLanUrl = 'http://192.168.0.19:8000';
  static const String fallbackEmulatorUrl = 'http://10.0.2.2:8000';
  static const String fallbackLoopbackUrl = 'http://127.0.0.1:8000';

  /// Timeout extendido (>= 60s) para tolerar el arranque en frío (cold start ~53s) de Render.
  static const Duration requestTimeout = Duration(seconds: 70);

  /// Timeout rápido para candidatos en red local LAN/USB.
  static const Duration localCandidateTimeout = Duration(seconds: 5);

  /// Timeout extendido para subida de capturas OCR Fitdays/Whoop + procesamiento Gemini Vision.
  static const Duration ocrUploadTimeout = Duration(seconds: 90);
}
