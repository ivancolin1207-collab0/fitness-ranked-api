import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../data/services/api_client_service.dart';

export '../../data/services/api_client_service.dart';

typedef ApiClient = ApiClientService;

/// Utilidad centralizada de filtrado de respuestas HTTP para evitar que páginas HTML
/// de pasarela (502, 503, 504 de Render / Cloudflare) se muestren en la interfaz.
class ApiErrorSanitizer {
  const ApiErrorSanitizer._();

  static const String cloudReconnectingMessage =
      'Servidor reconectando en la nube. Reintentando...';

  static bool isHtmlOrGatewayError(int? statusCode, String? rawBody) {
    if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
      return true;
    }
    final String trimmed = (rawBody ?? '').trimLeft();
    final String lower = trimmed.toLowerCase();
    return lower.startsWith('<!doctype html') ||
        lower.startsWith('<html') ||
        lower.contains('<!doctype html>') ||
        lower.contains('<title>502</title>') ||
        lower.contains('bad gateway');
  }

  static String sanitizeResponseError(
    http.Response response, {
    String? fallbackMessage,
  }) {
    final String rawBody = response.body.trim();
    if (isHtmlOrGatewayError(response.statusCode, rawBody)) {
      return cloudReconnectingMessage;
    }
    try {
      final dynamic decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic> && decoded['detail'] != null) {
        final String detail = decoded['detail'].toString().trim();
        if (isHtmlOrGatewayError(response.statusCode, detail)) {
          return cloudReconnectingMessage;
        }
        return detail;
      }
    } catch (_) {}
    if (rawBody.isEmpty) {
      return fallbackMessage ?? cloudReconnectingMessage;
    }
    if (rawBody.length > 220) {
      return '${rawBody.substring(0, 220)}...';
    }
    return rawBody;
  }

  static String sanitizeRawErrorString(Object error) {
    final String raw = error
        .toString()
        .replaceFirst('HttpException: ', '')
        .replaceFirst('Exception: ', '')
        .trim();
    if (isHtmlOrGatewayError(null, raw) ||
        raw.contains('Error HTTP 502') ||
        raw.contains('Error HTTP 503') ||
        raw.contains('Error HTTP 504') ||
        raw.contains('HTTP 502') ||
        raw.contains('HTTP 503') ||
        raw.contains('HTTP 504')) {
      return cloudReconnectingMessage;
    }
    return raw;
  }
}
