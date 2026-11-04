import 'dart:io';
import '../models/auth_models.dart';
import '../models/biometric_models.dart';
import '../models/leaderboard_models.dart';
import '../models/workout_models.dart';
import '../services/api_client_service.dart';
import '../services/health_connect_service.dart';
import '../services/secure_storage_service.dart';

class FitnessRepository {
  final ApiClientService _apiClient;
  final HealthConnectService _healthConnectService;
  final SecureStorageService _storageService;

  FitnessRepository({
    required ApiClientService apiClient,
    required HealthConnectService healthConnectService,
    required SecureStorageService storageService,
  })  : _apiClient = apiClient,
        _healthConnectService = healthConnectService,
        _storageService = storageService;

  String get currentApiBaseUrl => _apiClient.baseUrl;

  Future<void> initializeSavedApiUrl() async {
    final String? savedUrl = await _storageService.readApiBaseUrl();
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _apiClient.setBaseUrl(savedUrl);
    }
  }

  Future<void> setCustomApiBaseUrl(String newUrl) async {
    _apiClient.setBaseUrl(newUrl);
    await _storageService.saveApiBaseUrl(_apiClient.baseUrl);
  }

  Future<ServerHealthCheckModel> checkServerHealth({
    String? specificUrl,
  }) async {
    final ServerHealthCheckModel status = await _apiClient.checkServerHealth(
      specificUrl: specificUrl,
    );
    if (status.isOnline) {
      await _storageService.saveApiBaseUrl(status.activeBaseUrl);
    }
    return status;
  }

  Future<String> getPreferredUnitSystem() {
    return _storageService.readUnitSystem();
  }

  Future<void> setPreferredUnitSystem(String unit) {
    return _storageService.saveUnitSystem(unit);
  }

  Future<String> getPreferredWearable() {
    return _storageService.readPreferredWearable();
  }

  Future<void> setPreferredWearable(String source) {
    return _storageService.savePreferredWearable(source);
  }

  Future<String?> getStoredJwtToken() {
    return _storageService.readJwtToken();
  }

  Future<String> _requireToken() async {
    final String? token = await _storageService.readJwtToken();
    if (token == null || token.isEmpty) {
      throw const HttpException(
        'Sesión no autenticada. Inicia sesión para continuar.',
      );
    }
    return token;
  }

  // =========================================================================
  // 1. AUTENTICACIÓN Y PERFIL
  // =========================================================================

  Future<UserProfileModel> login({
    required String email,
    required String password,
  }) async {
    final AuthTokenResponseModel tokenRes = await _apiClient.login(
      email: email,
      password: password,
    );
    await _storageService.saveJwtToken(tokenRes.accessToken);
    final UserProfileModel profile = await _apiClient.fetchMyProfile(
      jwtToken: tokenRes.accessToken,
    );
    await _storageService.saveUnitSystem(profile.unitSystem);
    await _storageService.savePreferredWearable(profile.preferredWearable);
    return profile;
  }

  Future<UserProfileModel> register({
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
    final AuthTokenResponseModel tokenRes = await _apiClient.register(
      username: username,
      email: email,
      password: password,
      fullName: fullName,
      birthDate: birthDate,
      biologicalSex: biologicalSex,
      heightCm: heightCm,
      trainingGoal: trainingGoal,
      preferredWearable: preferredWearable,
      unitSystem: unitSystem,
    );
    await _storageService.saveJwtToken(tokenRes.accessToken);
    final UserProfileModel profile = await _apiClient.fetchMyProfile(
      jwtToken: tokenRes.accessToken,
    );
    await _storageService.saveUnitSystem(profile.unitSystem);
    await _storageService.savePreferredWearable(profile.preferredWearable);
    return profile;
  }

  Future<UserProfileModel?> fetchCurrentSessionProfile() async {
    final String? token = await _storageService.readJwtToken();
    if (token == null || token.isEmpty) {
      return null;
    }
    try {
      final UserProfileModel profile = await _apiClient.fetchMyProfile(
        jwtToken: token,
      );
      await _storageService.saveUnitSystem(profile.unitSystem);
      await _storageService.savePreferredWearable(profile.preferredWearable);
      return profile;
    } catch (_) {
      return null;
    }
  }

  Future<UserProfileModel> completeProfileSetup(
    ProfileSetupRequestModel payload,
  ) async {
    final String token = await _requireToken();
    final UserProfileModel updated = await _apiClient.updateProfileSetup(
      payload: payload,
      jwtToken: token,
    );
    await _storageService.saveUnitSystem(updated.unitSystem);
    await _storageService.savePreferredWearable(updated.preferredWearable);
    return updated;
  }

  Future<void> logout() async {
    await _storageService.clearSession();
  }

  // =========================================================================
  // 2. BIOMETRÍA Y WEARABLE REAL (WHOOP / HEALTH CONNECT)
  // =========================================================================

  /// Intenta leer telemetría real desde Health Connect (alimentada por Whoop/Huawei)
  /// y sincronizarla en PostgreSQL. Si Health Connect no reporta datos hoy,
  /// consulta si ya existe un registro sincronizado hoy en PostgreSQL (`GET /wearables/today`).
  /// Si tampoco existe, retorna `null` para mostrar "Esperando sincronización de Whoop".
  Future<WearableMetricRecord?> syncTodayWearableData({
    String? sourceDevice,
    bool forceSensorPoll = false,
  }) async {
    final String token = await _requireToken();
    final String preferred =
        sourceDevice ?? await _storageService.readPreferredWearable();

    final WearableMetricRecord? sensorMetrics =
        await _healthConnectService.fetchTodayWearableMetrics(
      preferredSource: preferred,
    );
    if (sensorMetrics != null) {
      return _apiClient.syncWearableMetrics(
        record: sensorMetrics,
        jwtToken: token,
      );
    }

    if (forceSensorPoll) {
      return _apiClient.fetchTodayWearable(jwtToken: token);
    }

    return _apiClient.fetchTodayWearable(jwtToken: token);
  }

  /// Permite sincronizar directamente un payload real de telemetría wearable hacia PostgreSQL.
  Future<WearableMetricRecord> pushWearableRecord(
    WearableMetricRecord record,
  ) async {
    final String token = await _requireToken();
    return _apiClient.syncWearableMetrics(
      record: record,
      jwtToken: token,
    );
  }

  Future<BiometricRecord?> loadLatestBiometrics() async {
    final String token = await _requireToken();
    return _apiClient.fetchLatestBiometrics(jwtToken: token);
  }

  Future<List<BiometricRecord>> loadBiometricsHistory() async {
    final String token = await _requireToken();
    return _apiClient.fetchBiometricsHistory(jwtToken: token);
  }

  /// Escanea screenshot Fitdays con Gemini Vision y devuelve las métricas
  /// para autocompletar el formulario antes de guardar.
  Future<FitdaysExtractedMetricsModel> extractFitdaysOcrForForm(
    File imageFile,
  ) async {
    final String token = await _requireToken();
    return _apiClient.extractFitdaysOcrMetrics(
      imageFile: imageFile,
      jwtToken: token,
    );
  }

  /// Guarda las métricas de bioimpedancia (manuales o revisadas tras OCR) en Render PostgreSQL.
  Future<BiometricRecord> saveBiometrics(
    FitdaysExtractedMetricsModel payload,
  ) async {
    final String token = await _requireToken();
    return _apiClient.saveBiometricRecord(
      payload: payload,
      jwtToken: token,
    );
  }

  // =========================================================================
  // 3. RUTINAS SEMANALES, ROLLOVER Y ENTRENO ADAPTATIVO EN VIVO
  // =========================================================================

  Future<List<RoutineTemplateModel>> loadWeeklyRoutines() async {
    final String token = await _requireToken();
    return _apiClient.fetchRoutines(jwtToken: token);
  }

  Future<RoutineTemplateModel> saveRoutineForDay({
    required int dayOfWeek,
    required String name,
    required String focusGroup,
    required List<Map<String, dynamic>> exercises,
  }) async {
    final String token = await _requireToken();
    return _apiClient.upsertRoutineByDay(
      dayOfWeek: dayOfWeek,
      name: name,
      focusGroup: focusGroup,
      exercises: exercises,
      jwtToken: token,
    );
  }

  Future<TodayWorkoutPlanModel> loadTodayWorkoutPlan() async {
    final String token = await _requireToken();
    return _apiClient.fetchTodayWorkoutPlan(jwtToken: token);
  }

  Future<WorkoutSessionModel> startWorkoutFromRoutine({
    required String routineId,
    required bool isRollover,
  }) async {
    final String token = await _requireToken();
    return _apiClient.startWorkoutFromRoutine(
      routineId: routineId,
      isRollover: isRollover,
      jwtToken: token,
    );
  }

  Future<SetExecutionFeedbackResponseModel> registerSetAndRecalculate({
    required String workoutId,
    required SetExecutionFeedbackRequestModel feedback,
  }) async {
    final String token = await _requireToken();
    return _apiClient.submitSetFeedback(
      workoutId: workoutId,
      feedback: feedback,
      jwtToken: token,
    );
  }

  // =========================================================================
  // 4. ARENA RANKED Y MATCHMAKING 1v1
  // =========================================================================

  Future<LeaderboardResponseModel> loadLeaderboard({
    String seasonId = '2026-S4',
    String metricTarget = 'LBM_ALLOMETRIC_RATIO',
  }) async {
    final String token = await _requireToken();
    return _apiClient.fetchLeaderboard(
      seasonId: seasonId,
      metricTarget: metricTarget,
      jwtToken: token,
    );
  }

  Future<List<OpponentSearchResultModel>> searchOpponentsByUsername(
    String query,
  ) async {
    final String token = await _requireToken();
    return _apiClient.searchOpponents(query: query, jwtToken: token);
  }

  Future<HeadToHeadDuelModel?> loadActiveDuel({
    String seasonId = '2026-S4',
  }) async {
    final String token = await _requireToken();
    return _apiClient.fetchActiveDuel(seasonId: seasonId, jwtToken: token);
  }

  Future<HeadToHeadDuelModel> challengeOpponentByUsername({
    required String opponentUsername,
    required String metricTarget,
    String seasonId = '2026-S4',
  }) async {
    final String token = await _requireToken();
    return _apiClient.challengeOpponentByUsername(
      opponentUsername: opponentUsername,
      metricTarget: metricTarget,
      seasonId: seasonId,
      jwtToken: token,
    );
  }

  Future<HeadToHeadDuelModel> matchmakeAutomatic({
    required String metricTarget,
    int eloTolerance = 100,
    String seasonId = '2026-S4',
  }) async {
    final String token = await _requireToken();
    return _apiClient.matchmakeByElo(
      metricTarget: metricTarget,
      eloTolerance: eloTolerance,
      seasonId: seasonId,
      jwtToken: token,
    );
  }
}
