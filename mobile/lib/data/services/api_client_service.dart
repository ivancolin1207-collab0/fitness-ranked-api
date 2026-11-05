import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
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
      return 'El Web Service ($_baseUrl) respondió 404 (aún no desplegado en Render) y no se detectó servidor local en ${ApiConstants.fallbackLocalLanUrl}.';
    }
    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['detail'] != null) {
        return decoded['detail'].toString();
      }
    } catch (_) {}
    return 'Error HTTP ${response.statusCode}: ${response.body}';
  }

  Future<http.Response> _sendWithFallback(
    Future<http.Response> Function(String candidateBase) requestFn,
  ) async {
    Object? lastError;
    http.Response? unprovisionedResponse;

    for (final String candidate in _candidateBaseUrls()) {
      try {
        final http.Response response = await requestFn(candidate).timeout(
          _timeoutForCandidate(candidate),
        );
        if (_isUnprovisionedServerResponse(response)) {
          unprovisionedResponse ??= response;
          continue;
        }
        _baseUrl = candidate;
        return response;
      } on SocketException catch (e) {
        lastError = e;
      } on TimeoutException catch (e) {
        lastError = e;
      } on http.ClientException catch (e) {
        lastError = e;
      }
    }

    if (unprovisionedResponse != null) {
      return unprovisionedResponse;
    }

    throw HttpException(
      'No se pudo conectar a $_baseUrl ni al servidor local (${ApiConstants.fallbackLocalLanUrl}). Verifica que el Web Service esté activo en Render o que uvicorn corra con --host 0.0.0.0. Detalle: $lastError',
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
    String biologicalSex = 'MALE',
    double heightCm = 175.0,
    String trainingGoal = 'HIPERTROFIA',
    String preferredWearable = 'WHOOP',
    String unitSystem = 'KG',
  }) async {
    final String? birthYmd = birthDate != null
        ? '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}'
        : null;

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
          'biological_sex': biologicalSex,
          'height_cm': heightCm,
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

  // =========================================================================
  // 2. BIOMETRÍA (CAPTURA MANUAL + OCR FITDAYS) Y WEARABLES
  // =========================================================================

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
}
