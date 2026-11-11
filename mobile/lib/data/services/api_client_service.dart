import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/services/ocr_service.dart';
import '../models/auth_models.dart';
import '../models/biometric_models.dart';
import '../models/leaderboard_models.dart';
import '../models/workout_models.dart';

/// Función top-level para parsear el Leaderboard en un Isolate secundario (`compute()`).
LeaderboardResponseModel parseLeaderboardIsolate(String responseBody) {
  final Map<String, dynamic> decoded =
      jsonDecode(responseBody) as Map<String, dynamic>;
  return LeaderboardResponseModel.fromJson(decoded);
}

class ApiClientService {
  final http.Client _httpClient;
  String _baseUrl;

  ApiClientService({
    http.Client? httpClient,
    String? customBaseUrl,
  })  : _httpClient = httpClient ?? http.Client(),
        _baseUrl = customBaseUrl ?? _resolveDefaultBaseUrl();

  String get baseUrl => _baseUrl;

  void setBaseUrl(String newUrl) {
    final String cleaned = newUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (cleaned.isNotEmpty) {
      _baseUrl = cleaned;
    }
  }

  static String _resolveDefaultBaseUrl() {
    const String envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    return ApiConstants.defaultProductionBaseUrl;
  }

  List<String> _candidateBaseUrls() {
    final List<String> candidates = <String>[
      _baseUrl,
      ApiConstants.defaultProductionBaseUrl,
      ApiConstants.fallbackLocalLanUrl,
      ApiConstants.fallbackEmulatorUrl,
      ApiConstants.fallbackLoopbackUrl,
    ];
    final Set<String> seen = <String>{};
    return candidates.where((String u) => seen.add(u)).toList();
  }

  Duration _timeoutForCandidate(String candidate) {
    if (candidate.contains('onrender.com')) {
      return ApiConstants.requestTimeout;
    }
    return ApiConstants.localCandidateTimeout;
  }

  bool _isUnprovisionedServerResponse(http.Response response) {
    final String? renderRouting = response.headers['x-render-routing'];
    if (renderRouting != null && renderRouting.contains('no-server')) {
      return true;
    }
    if (response.statusCode == 404) {
      final String trimmed = response.body.trim();
      // Las respuestas 404 de nuestro backend FastAPI siempre son JSON con {"detail": ...}
      if (!trimmed.startsWith('{')) {
        return true;
      }
    }
    return false;
  }

  Map<String, String> _buildHeaders(String? jwtToken) {
    return <String, String>{
      HttpHeaders.acceptHeader: 'application/json',
      HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
      if (jwtToken != null && jwtToken.isNotEmpty)
        HttpHeaders.authorizationHeader: 'Bearer $jwtToken',
    };
  }

  String _extractErrorDetail(http.Response response) {
    if (_isUnprovisionedServerResponse(response)) {
      return ApiErrorSanitizer.cloudReconnectingMessage;
    }
    if (ApiErrorSanitizer.isHtmlOrGatewayError(
      response.statusCode,
      response.body,
    )) {
      return ApiErrorSanitizer.cloudReconnectingMessage;
    }
    return ApiErrorSanitizer.sanitizeResponseError(response);
  }

  Future<http.Response> _sendWithFallback(
    Future<http.Response> Function(String candidateBase) requestFn,
  ) async {
    http.Response? unprovisionedResponse;

    for (final String candidate in _candidateBaseUrls()) {
      try {
        http.Response response = await requestFn(candidate).timeout(
          _timeoutForCandidate(candidate),
        );
        // Si Render está despertando (502/503/504), reintentar automáticamente tras breve pausa
        if (response.statusCode == 502 ||
            response.statusCode == 503 ||
            response.statusCode == 504) {
          await Future<void>.delayed(const Duration(milliseconds: 900));
          response = await requestFn(candidate).timeout(
            _timeoutForCandidate(candidate),
          );
        }
        if (_isUnprovisionedServerResponse(response)) {
          unprovisionedResponse ??= response;
          continue;
        }
        _baseUrl = candidate;
        return response;
      } on SocketException {
        continue;
      } on TimeoutException {
        continue;
      } on http.ClientException {
        continue;
      }
    }

    if (unprovisionedResponse != null) {
      return unprovisionedResponse;
    }

    throw const HttpException(
      ApiErrorSanitizer.cloudReconnectingMessage,
    );
  }

  // =========================================================================
  // 0. PING / HEALTHCHECK DE CONECTIVIDAD (/health y /docs)
  // =========================================================================

  Future<ServerHealthCheckModel> checkServerHealth({
    String? specificUrl,
  }) async {
    final List<String> candidates = specificUrl != null &&
            specificUrl.trim().isNotEmpty
        ? <String>[specificUrl.trim().replaceAll(RegExp(r'/+$'), '')]
        : _candidateBaseUrls();

    int? firstStatusCode;
    String? firstAttemptedUrl;

    for (final String candidate in candidates) {
      firstAttemptedUrl ??= candidate;
      final Stopwatch sw = Stopwatch()..start();
      try {
        final http.Response res = await _httpClient
            .get(
              Uri.parse('$candidate/health'),
              headers: _buildHeaders(null),
            )
            .timeout(_timeoutForCandidate(candidate));
        sw.stop();

        firstStatusCode ??= res.statusCode;

        if (res.statusCode == 200 && !_isUnprovisionedServerResponse(res)) {
          _baseUrl = candidate;
          return ServerHealthCheckModel(
            isOnline: true,
            activeBaseUrl: candidate,
            statusCode: 200,
            latencyMs: sw.elapsedMilliseconds,
            message:
                'Backend activo en $candidate (${sw.elapsedMilliseconds} ms) • PostgreSQL Render conectado.',
          );
        }

        // Probar /docs como verificación secundaria si /health no respondió 200
        if (!_isUnprovisionedServerResponse(res)) {
          final http.Response docsRes = await _httpClient
              .get(Uri.parse('$candidate/docs'))
              .timeout(const Duration(seconds: 5));
          if (docsRes.statusCode == 200) {
            _baseUrl = candidate;
            return ServerHealthCheckModel(
              isOnline: true,
              activeBaseUrl: candidate,
              statusCode: 200,
              latencyMs: sw.elapsedMilliseconds,
              message:
                  'Backend FastAPI detectado en $candidate (/docs activo).',
            );
          }
        }
      } catch (_) {
        sw.stop();
      }
    }

    final String target = firstAttemptedUrl ?? _baseUrl;
    if (firstStatusCode == 404) {
      return ServerHealthCheckModel(
        isOnline: false,
        activeBaseUrl: target,
        statusCode: 404,
        message:
            'HTTP 404 en $target: El Web Service aún no está desplegado en Render y el backend local (${ApiConstants.fallbackLocalLanUrl}) no está encendido.',
      );
    }

    return ServerHealthCheckModel(
      isOnline: false,
      activeBaseUrl: target,
      statusCode: firstStatusCode,
      message:
          'Servidor inalcanzable ($target). Despliega el Web Service en Render o inicia en tu Mac: uvicorn app.main:app --host 0.0.0.0 --port 8000',
    );
  }

  // =========================================================================
  // 1. AUTENTICACIÓN Y PERFIL
  // =========================================================================

  Future<AuthTokenResponseModel> login({
    required String email,
    required String password,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.post(
        Uri.parse('$base/api/v1/auth/login'),
        headers: _buildHeaders(null),
        body: jsonEncode(<String, dynamic>{
          'email': email.trim(),
          'password': password,
        }),
      ),
    );

    if (response.statusCode == 200) {
      return AuthTokenResponseModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw HttpException(_extractErrorDetail(response));
  }

  Future<AuthTokenResponseModel> register({
    required String username,
    required String email,
    required String password,
    String? fullName,
    DateTime? birthDate,
    required String biologicalSex,
    double? heightCm,
    double? weightKg,
    double? bodyFatPct,
    String trainingGoal = 'HIPERTROFIA',
    String preferredWearable = 'WHOOP',
    String unitSystem = 'KG',
  }) async {
    final String? birthYmd = birthDate != null
        ? '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}'
        : null;
    final bool isFemale = biologicalSex.toUpperCase() == 'FEMALE' ||
        biologicalSex.toLowerCase() == 'female';

    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.post(
        Uri.parse('$base/api/v1/auth/register'),
        headers: _buildHeaders(null),
        body: jsonEncode(<String, dynamic>{
          'username': username.trim(),
          'email': email.trim(),
          'password': password,
          if (fullName != null && fullName.trim().isNotEmpty)
            'full_name': fullName.trim(),
          if (birthYmd != null) 'birth_date': birthYmd,
          'sex': isFemale ? 'female' : 'male',
          'biological_sex': isFemale ? 'FEMALE' : 'MALE',
          if (heightCm != null) 'height_cm': heightCm,
          if (weightKg != null) 'weight_kg': weightKg,
          if (bodyFatPct != null) 'body_fat_pct': bodyFatPct,
          'training_goal': trainingGoal,
          'preferred_wearable': preferredWearable,
          'unit_system': unitSystem,
        }),
      ),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return AuthTokenResponseModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw HttpException(_extractErrorDetail(response));
  }

  Future<UserProfileModel> fetchMyProfile({
    required String jwtToken,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.get(
        Uri.parse('$base/api/v1/auth/me'),
        headers: _buildHeaders(jwtToken),
      ),
    );

    if (response.statusCode == 200) {
      return UserProfileModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw HttpException(_extractErrorDetail(response));
  }

  Future<UserProfileModel> updateProfileSetup({
    required ProfileSetupRequestModel payload,
    required String jwtToken,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.put(
        Uri.parse('$base/api/v1/auth/profile'),
        headers: _buildHeaders(jwtToken),
        body: jsonEncode(payload.toJson()),
      ),
    );

    if (response.statusCode == 200) {
      return UserProfileModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw HttpException(_extractErrorDetail(response));
  }

  /// POST /api/v1/auth/forgot-password-direct
  Future<AuthTokenResponseModel> resetPasswordDirect({
    required String email,
    required String newPassword,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.post(
        Uri.parse('$base/api/v1/auth/forgot-password-direct'),
        headers: _buildHeaders(null),
        body: jsonEncode(<String, dynamic>{
          'email': email.trim(),
          'new_password': newPassword,
        }),
      ),
    );

    if (response.statusCode == 200) {
      return AuthTokenResponseModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw HttpException(_extractErrorDetail(response));
  }

  // =========================================================================
  // 2. BIOMETRÍA (CAPTURA MANUAL + OCR FITDAYS), HIDRATACIÓN Y WEARABLES
  // =========================================================================

  /// GET /api/v1/biometrics/hydration/today
  Future<HydrationStatusModel> fetchTodayHydration({
    required String jwtToken,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.get(
        Uri.parse('$base/api/v1/biometrics/hydration/today'),
        headers: _buildHeaders(jwtToken),
      ),
    );

    if (response.statusCode == 200) {
      return HydrationStatusModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw HttpException(_extractErrorDetail(response));
  }

  /// POST /api/v1/biometrics/hydration
  Future<HydrationStatusModel> addHydrationLog({
    required int amountMl,
    required String jwtToken,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.post(
        Uri.parse('$base/api/v1/biometrics/hydration'),
        headers: _buildHeaders(jwtToken),
        body: jsonEncode(<String, dynamic>{
          'amount_ml': amountMl,
        }),
      ),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return HydrationStatusModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw HttpException(_extractErrorDetail(response));
  }

  /// POST /api/v1/biometrics/scan (Extracción OCR con Gemini Vision para autocompletar formulario)
  Future<FitdaysExtractedMetricsModel> extractFitdaysOcrMetrics({
    required File imageFile,
    required String jwtToken,
  }) async {
    final Uri uri = Uri.parse('$_baseUrl/api/v1/biometrics/scan');
    const OcrService ocrService = OcrService();
    return ocrService.scanFitdaysReport(
      imageFile: imageFile,
      endpointUri: uri,
      accessToken: jwtToken,
      httpClient: _httpClient,
    );
  }

  /// POST /api/v1/biometrics (Guarda el formulario manual o revisado tras OCR)
  Future<BiometricRecord> saveBiometricRecord({
    required FitdaysExtractedMetricsModel payload,
    required String jwtToken,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.post(
        Uri.parse('$base/api/v1/biometrics'),
        headers: _buildHeaders(jwtToken),
        body: jsonEncode(payload.toJson()),
      ),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      return BiometricRecord.fromJson(data);
    }
    throw HttpException(_extractErrorDetail(response));
  }

  /// GET /api/v1/biometrics/latest
  Future<BiometricRecord?> fetchLatestBiometrics({
    required String jwtToken,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.get(
        Uri.parse('$base/api/v1/biometrics/latest'),
        headers: _buildHeaders(jwtToken),
      ),
    );

    if (response.statusCode == 200) {
      if (response.body.isEmpty || response.body == 'null') {
        return null;
      }
      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      return BiometricRecord.fromJson(data);
    }
    throw HttpException(_extractErrorDetail(response));
  }

  /// GET /api/v1/biometrics/history
  Future<List<BiometricRecord>> fetchBiometricsHistory({
    required String jwtToken,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.get(
        Uri.parse('$base/api/v1/biometrics/history'),
        headers: _buildHeaders(jwtToken),
      ),
    );

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map(
            (dynamic item) =>
                BiometricRecord.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }
    throw HttpException(_extractErrorDetail(response));
  }

  /// GET /api/v1/wearables/today
  Future<WearableMetricRecord?> fetchTodayWearable({
    required String jwtToken,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.get(
        Uri.parse('$base/api/v1/wearables/today'),
        headers: _buildHeaders(jwtToken),
      ),
    );

    if (response.statusCode == 200) {
      if (response.body.isEmpty || response.body == 'null') {
        return null;
      }
      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      return WearableMetricRecord.fromJson(data);
    }
    throw HttpException(_extractErrorDetail(response));
  }

  /// POST /api/v1/wearables/sync
  Future<WearableMetricRecord> syncWearableMetrics({
    required WearableMetricRecord record,
    required String jwtToken,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.post(
        Uri.parse('$base/api/v1/wearables/sync'),
        headers: _buildHeaders(jwtToken),
        body: jsonEncode(record.toSyncJson()),
      ),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      return WearableMetricRecord.fromJson(data);
    }
    throw HttpException(_extractErrorDetail(response));
  }

  /// POST /api/v1/wearables/scan-whoop
  Future<Map<String, dynamic>> scanWhoopScreenshotBytes({
    required Uint8List bytes,
    required String jwtToken,
    String sourceDevice = 'WHOOP',
  }) async {
    const OcrService ocrService = OcrService();
    return ocrService.scanWhoopScreenshotBytes(
      jpegBytes: bytes,
      baseUrl: _baseUrl,
      accessToken: jwtToken,
      httpClient: _httpClient,
      sourceDevice: sourceDevice,
    );
  }

  /// POST /api/v1/wearables/scan-screen
  Future<WearableMetricRecord> scanWhoopScreenMetrics({
    required File imageFile,
    required String jwtToken,
    String sourceDevice = 'WHOOP',
  }) async {
    final Uri uri = Uri.parse('$_baseUrl/api/v1/wearables/scan-screen');
    const OcrService ocrService = OcrService();
    return ocrService.scanWhoopScreenReport(
      imageFile: imageFile,
      endpointUri: uri,
      accessToken: jwtToken,
      httpClient: _httpClient,
      sourceDevice: sourceDevice,
    );
  }

  /// POST /api/v1/ai/chat (Centro Táctico • Director de Rendimiento)
  Future<AiCoachChatResponseModel> sendAiCoachChat({
    required String message,
    required List<AiCoachChatMessageModel> history,
    required Map<String, dynamic> athleteContext,
    required String jwtToken,
  }) async {
    try {
      final http.Response response = await _sendWithFallback(
        (String base) => _httpClient.post(
          Uri.parse('$base/api/v1/ai/chat'),
          headers: _buildHeaders(jwtToken),
          body: jsonEncode(<String, dynamic>{
            'message': message.trim(),
            'history':
                history.map((AiCoachChatMessageModel m) => m.toJson()).toList(),
            'athlete_context': athleteContext,
            ...athleteContext,
          }),
        ),
      );

      if (response.statusCode == 200) {
        final AiCoachChatResponseModel parsed =
            AiCoachChatResponseModel.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
        final String cleanReply = parsed.reply.trim();
        if (cleanReply.length >= 45 &&
            !cleanReply.endsWith('LBM') &&
            !cleanReply.endsWith('kg')) {
          return parsed;
        }
      }
    } catch (_) {}

    return _buildLocalCoachReply(
      message: message,
      context: athleteContext,
    );
  }

  AiCoachChatResponseModel _buildLocalCoachReply({
    required String message,
    required Map<String, dynamic> context,
  }) {
    final String name = (context['athlete_name'] as String?) ?? 'Atleta';
    final double? weightKg = (context['weight_kg'] as num?)?.toDouble();
    final double? lbmKg = (context['lean_body_mass_kg'] as num?)?.toDouble();
    final double? rec = (context['recovery_score'] as num?)?.toDouble();
    final double? sleepPct =
        (context['sleep_performance_pct'] as num?)?.toDouble();
    final double? strain = (context['strain_score'] as num?)?.toDouble();
    final double? stress = (context['stress_level'] as num?)?.toDouble();
    final String stressCat = (context['stress_category'] as String?) ??
        (stress != null
            ? (stress >= 2.0 ? 'ALTO' : (stress >= 1.0 ? 'MEDIO' : 'BAJO'))
            : 'SIN DATOS');
    final int hydConsumed =
        (context['hydration_consumed_ml'] as num?)?.toInt() ?? 0;
    final int? hydGoal = (context['hydration_goal_ml'] as num?)?.toInt();
    final String routine = (context['scheduled_routine_name'] as String?) ??
        'Sesión de Fuerza Programada';

    final String zone = rec == null
        ? 'SIN_SINCRONIZAR'
        : (rec >= 67.0 ? 'VERDE' : (rec >= 34.0 ? 'AMARILLA' : 'ROJA'));
    final String recTxt = rec != null ? '${rec.round()}%' : '--';
    final String sleepTxt = sleepPct != null ? '${sleepPct.round()}%' : '--';
    final String strainTxt =
        strain != null ? strain.toStringAsFixed(1) : '--';
    final String stressTxt =
        stress != null ? '${stress.toStringAsFixed(1)} ($stressCat)' : '--';
    final String weightTxt =
        weightKg != null ? '${weightKg.toStringAsFixed(1)} kg' : '--';
    final String lbmTxt =
        lbmKg != null ? '${lbmKg.toStringAsFixed(1)} kg LBM' : '--';
    final String hydGoalTxt = hydGoal != null ? '$hydGoal ml' : '--';

    final String directive = rec == null
        ? 'Escanea tu wearable de hoy para ajustar el RPE diario automáticamente.'
        : (zone == 'VERDE'
            ? 'Sobrecarga progresiva habilitada (+2.5 kg en básicos, RPE 8.5).'
            : (zone == 'AMARILLA'
                ? 'Mantén volumen objetivo con RPE controlado (7.5–8.0, RIR 2).'
                : 'Descarga técnica activa (-15% carga, RPE 6.5–7.0) para proteger el SNC.'));

    final String reply =
        'Resumen táctico con tus datos reales registrados ($name):\n'
        '• Biometría: $weightTxt | $lbmTxt\n'
        '• Recuperación hoy: $recTxt | Sueño: $sleepTxt\n'
        '• Esfuerzo (Strain): $strainTxt | Estrés: $stressTxt\n'
        '• Hidratación: $hydConsumed / $hydGoalTxt | Rutina: $routine\n\n'
        'Directriz para "${message.trim()}": $directive';

    return AiCoachChatResponseModel(
      reply: reply,
      readinessZone: zone,
      suggestedPrompts: const <String>[
        '¿Qué puedo hacer para subir de peso limpio?',
        'Ajusta mis series y RPE para la rutina de hoy',
        '¿Qué me recomiendas cenar según mi recuperación?',
        '¿Cuánta agua me falta antes de entrenar?',
      ],
    );
  }

  // =========================================================================
  // 3. RUTINAS SEMANALES, ROLLOVER Y ENTRENAMIENTO EN VIVO
  // =========================================================================

  Future<List<RoutineTemplateModel>> fetchRoutines({
    required String jwtToken,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.get(
        Uri.parse('$base/api/v1/workouts/routines'),
        headers: _buildHeaders(jwtToken),
      ),
    );

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map(
            (dynamic item) =>
                RoutineTemplateModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }
    throw HttpException(_extractErrorDetail(response));
  }

  Future<AiGeneratedRoutinePlanModel> fetchCurrentAiRoutine({
    required String jwtToken,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.get(
        Uri.parse('$base/api/v1/routines/current'),
        headers: _buildHeaders(jwtToken),
      ),
    );

    if (response.statusCode == 200) {
      return AiGeneratedRoutinePlanModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw HttpException(_extractErrorDetail(response));
  }

  Future<AiGeneratedRoutinePlanModel> generateAiRoutine({
    required String jwtToken,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient
          .post(
            Uri.parse('$base/api/v1/routines/generate-ai'),
            headers: _buildHeaders(jwtToken),
          )
          .timeout(const Duration(seconds: 75)),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return AiGeneratedRoutinePlanModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw HttpException(_extractErrorDetail(response));
  }

  Future<RoutineTemplateModel> upsertRoutineByDay({
    required int dayOfWeek,
    required String name,
    required String focusGroup,
    required List<Map<String, dynamic>> exercises,
    required String jwtToken,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.post(
        Uri.parse('$base/api/v1/workouts/routines'),
        headers: _buildHeaders(jwtToken),
        body: jsonEncode(<String, dynamic>{
          'day_of_week': dayOfWeek,
          'name': name.trim(),
          'focus_group': focusGroup.trim(),
          'exercises': exercises,
        }),
      ),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return RoutineTemplateModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw HttpException(_extractErrorDetail(response));
  }

  Future<TodayWorkoutPlanModel> fetchTodayWorkoutPlan({
    required String jwtToken,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.get(
        Uri.parse('$base/api/v1/workouts/today-plan'),
        headers: _buildHeaders(jwtToken),
      ),
    );

    if (response.statusCode == 200) {
      return TodayWorkoutPlanModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw HttpException(_extractErrorDetail(response));
  }

  Future<WorkoutSessionModel> startWorkoutFromRoutine({
    required String routineId,
    required bool isRollover,
    required String jwtToken,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.post(
        Uri.parse(
          '$base/api/v1/workouts/start-from-routine/$routineId?is_rollover=$isRollover',
        ),
        headers: _buildHeaders(jwtToken),
      ),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return WorkoutSessionModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw HttpException(_extractErrorDetail(response));
  }

  /// POST /api/v1/workouts/{workoutId}/sets
  Future<SetExecutionFeedbackResponseModel> submitSetFeedback({
    required String workoutId,
    required SetExecutionFeedbackRequestModel feedback,
    required String jwtToken,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.post(
        Uri.parse('$base/api/v1/workouts/$workoutId/sets'),
        headers: _buildHeaders(jwtToken),
        body: jsonEncode(feedback.toJson()),
      ),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      return SetExecutionFeedbackResponseModel.fromJson(data);
    }
    throw HttpException(_extractErrorDetail(response));
  }

  // =========================================================================
  // 4. ARENA RANKED Y MATCHMAKING 1v1
  // =========================================================================

  /// GET /api/v1/leaderboard
  Future<LeaderboardResponseModel> fetchLeaderboard({
    required String seasonId,
    required String metricTarget,
    required String jwtToken,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.get(
        Uri.parse('$base/api/v1/leaderboard').replace(
          queryParameters: <String, String>{
            'season_id': seasonId,
            'metric_target': metricTarget,
          },
        ),
        headers: _buildHeaders(jwtToken),
      ),
    );

    if (response.statusCode == 200) {
      return compute(parseLeaderboardIsolate, response.body);
    }
    throw HttpException(_extractErrorDetail(response));
  }

  /// GET /api/v1/leaderboard/users/search
  Future<List<OpponentSearchResultModel>> searchOpponents({
    required String query,
    required String jwtToken,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.get(
        Uri.parse('$base/api/v1/leaderboard/users/search').replace(
          queryParameters: <String, String>{'q': query.trim()},
        ),
        headers: _buildHeaders(jwtToken),
      ),
    );

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map(
            (dynamic item) => OpponentSearchResultModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
    }
    throw HttpException(_extractErrorDetail(response));
  }

  /// GET /api/v1/leaderboard/duels/active
  Future<HeadToHeadDuelModel?> fetchActiveDuel({
    required String seasonId,
    required String jwtToken,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.get(
        Uri.parse('$base/api/v1/leaderboard/duels/active').replace(
          queryParameters: <String, String>{'season_id': seasonId},
        ),
        headers: _buildHeaders(jwtToken),
      ),
    );

    if (response.statusCode == 200) {
      if (response.body.isEmpty || response.body == 'null') {
        return null;
      }
      return HeadToHeadDuelModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw HttpException(_extractErrorDetail(response));
  }

  /// POST /api/v1/leaderboard/duels/challenge
  Future<HeadToHeadDuelModel> challengeOpponentByUsername({
    required String opponentUsername,
    required String metricTarget,
    required String seasonId,
    required String jwtToken,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.post(
        Uri.parse('$base/api/v1/leaderboard/duels/challenge'),
        headers: _buildHeaders(jwtToken),
        body: jsonEncode(<String, dynamic>{
          'opponent_username': opponentUsername.trim(),
          'metric_target': metricTarget,
          'season_id': seasonId,
        }),
      ),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return HeadToHeadDuelModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw HttpException(_extractErrorDetail(response));
  }

  /// POST /api/v1/leaderboard/duels/matchmake
  Future<HeadToHeadDuelModel> matchmakeByElo({
    required String metricTarget,
    required int eloTolerance,
    required String seasonId,
    required String jwtToken,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.post(
        Uri.parse('$base/api/v1/leaderboard/duels/matchmake'),
        headers: _buildHeaders(jwtToken),
        body: jsonEncode(<String, dynamic>{
          'metric_target': metricTarget,
          'elo_tolerance': eloTolerance,
          'season_id': seasonId,
        }),
      ),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return HeadToHeadDuelModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw HttpException(_extractErrorDetail(response));
  }

  /// GET /api/v1/leaderboard/squads
  Future<List<SquadLeaderboardEntryModel>> fetchSquadsLeaderboard({
    required String jwtToken,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.get(
        Uri.parse('$base/api/v1/leaderboard/squads'),
        headers: _buildHeaders(jwtToken),
      ),
    );

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(SquadLeaderboardEntryModel.fromJson)
          .toList();
    }
    throw HttpException(_extractErrorDetail(response));
  }

  /// POST /api/v1/leaderboard/squads/join
  Future<List<SquadLeaderboardEntryModel>> joinOrCreateSquad({
    required String squadName,
    required String squadTag,
    required String jwtToken,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.post(
        Uri.parse('$base/api/v1/leaderboard/squads/join'),
        headers: _buildHeaders(jwtToken),
        body: jsonEncode(<String, dynamic>{
          'squad_name': squadName.trim(),
          'squad_tag': squadTag.trim().toUpperCase(),
        }),
      ),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(SquadLeaderboardEntryModel.fromJson)
          .toList();
    }
    throw HttpException(_extractErrorDetail(response));
  }

  /// GET /api/v1/leaderboard/duels/2v2
  Future<ActiveDuo2v2DuelModel?> fetchActive2v2Duel({
    required String seasonId,
    required String jwtToken,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.get(
        Uri.parse('$base/api/v1/leaderboard/duels/2v2').replace(
          queryParameters: <String, String>{'season_id': seasonId},
        ),
        headers: _buildHeaders(jwtToken),
      ),
    );

    if (response.statusCode == 200) {
      if (response.body.isEmpty || response.body.trim() == 'null') {
        return null;
      }
      return ActiveDuo2v2DuelModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw HttpException(_extractErrorDetail(response));
  }

  /// POST /api/v1/leaderboard/duels/2v2/invite
  Future<ActiveDuo2v2DuelModel> invitePartner2v2Duel({
    required String partnerUsername,
    required String duoName,
    required String jwtToken,
  }) async {
    final http.Response response = await _sendWithFallback(
      (String base) => _httpClient.post(
        Uri.parse('$base/api/v1/leaderboard/duels/2v2/invite'),
        headers: _buildHeaders(jwtToken),
        body: jsonEncode(<String, dynamic>{
          'partner_username': partnerUsername.trim(),
          'duo_name': duoName.trim(),
        }),
      ),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return ActiveDuo2v2DuelModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw HttpException(_extractErrorDetail(response));
  }
}
