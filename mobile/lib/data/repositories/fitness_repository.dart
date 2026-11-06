import 'dart:io';
import 'dart:typed_data';
import '../../core/services/auth_service.dart';
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
  final AuthService _authService;

  FitnessRepository({
    required ApiClientService apiClient,
    required HealthConnectService healthConnectService,
    required SecureStorageService storageService,
    AuthService? authService,
  })  : _apiClient = apiClient,
        _healthConnectService = healthConnectService,
        _storageService = storageService,
        _authService =
            authService ?? AuthService(storageService: storageService);

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

  /// Lee el género del atleta (`'male'` o `'female'`) desde el perfil autenticado en caché.
  Future<String> getAthleteGender() async {
    final UserProfileModel? cached =
        await _storageService.readUserProfileCache();
    final String rawSex = (cached?.biologicalSex ?? 'MALE').toLowerCase().trim();
    if (rawSex.contains('fem') || rawSex == 'f' || rawSex.contains('mujer')) {
      return 'female';
    }
    return 'male';
  }

  /// Actualiza el género del avatar en el perfil persistido localmente.
  Future<void> setAthleteGender(String gender) async {
    final String normalized =
        gender.toLowerCase().contains('fem') ? 'FEMALE' : 'MALE';
    final UserProfileModel? cached =
        await _storageService.readUserProfileCache();
    if (cached != null) {
      await _storageService.saveUserProfileCache(
        cached.copyWith(biologicalSex: normalized),
      );
    }
  }

  Future<String?> getStoredJwtToken() {
    return _authService.readActiveJwtToken();
  }

  Future<UserProfileModel?> getCurrentUserProfileCache() {
    return _storageService.readUserProfileCache();
  }

  Future<String> _requireToken() async {
    final String? token = await _authService.readActiveJwtToken();
    if (token == null || token.isEmpty) {
      throw const HttpException(
        'Sesión no autenticada. Inicia sesión para continuar.',
      );
    }
    return token;
  }

  // =========================================================================
  // 1. AUTENTICACIÓN, AUTO-LOGIN PERSISTENTE Y RECUPERACIÓN DE CUENTA
  // =========================================================================

  /// Verifica si existe un token JWT válido en disco y restaura de inmediato
  /// el perfil persistido para saltar directo a la pantalla principal (Auto-login).
  Future<UserProfileModel?> restoreCachedSessionProfile() async {
    final String? token = await _authService.readActiveJwtToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    final UserProfileModel? cached =
        await _storageService.readUserProfileCache();
    if (cached != null) {
      return cached;
    }

    final String savedUnit = await _storageService.readUnitSystem();
    final String savedWearable = await _storageService.readPreferredWearable();
    final String? savedUserId = await _authService.readActiveUserId();

    final UserProfileModel fallback = UserProfileModel(
      id: savedUserId ?? 'persisted-session',
      username: 'atleta_activo',
      fullName: 'Atleta ApexMetrix',
      maskedEmail: '',
      biologicalSex: 'MALE',
      heightCm: 175.0,
      trainingGoal: 'HIPERTROFIA',
      preferredWearable: savedWearable,
      unitSystem: savedUnit,
      onboardingCompleted: true,
      currentElo: 1200,
      currentTier: 'Plata',
      createdAt: DateTime.now(),
    );
    await _authService.persistSession(
      jwtToken: token,
      userId: fallback.id,
      profile: fallback,
    );
    return fallback;
  }

  Future<UserProfileModel> login({
    required String email,
    required String password,
  }) async {
    final AuthTokenResponseModel tokenRes = await _apiClient.login(
      email: email,
      password: password,
    );
    final UserProfileModel profile = tokenRes.user ??
        await _apiClient.fetchMyProfile(
          jwtToken: tokenRes.accessToken,
        );
    await _authService.persistSession(
      jwtToken: tokenRes.accessToken,
      userId: profile.id,
      profile: profile,
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
    final UserProfileModel profile = tokenRes.user ??
        await _apiClient.fetchMyProfile(
          jwtToken: tokenRes.accessToken,
        );
    await _authService.persistSession(
      jwtToken: tokenRes.accessToken,
      userId: profile.id,
      profile: profile,
    );
    await _storageService.saveUnitSystem(profile.unitSystem);
    await _storageService.savePreferredWearable(profile.preferredWearable);
    return profile;
  }

  Future<UserProfileModel> resetPasswordDirect({
    required String email,
    required String newPassword,
  }) async {
    final AuthTokenResponseModel tokenRes =
        await _apiClient.resetPasswordDirect(
      email: email,
      newPassword: newPassword,
    );
    final UserProfileModel profile = tokenRes.user ??
        await _apiClient.fetchMyProfile(
          jwtToken: tokenRes.accessToken,
        );
    await _authService.persistSession(
      jwtToken: tokenRes.accessToken,
      userId: profile.id,
      profile: profile,
    );
    await _storageService.saveUnitSystem(profile.unitSystem);
    await _storageService.savePreferredWearable(profile.preferredWearable);
    return profile;
  }

  Future<UserProfileModel?> fetchCurrentSessionProfile() async {
    final String? token = await _authService.readActiveJwtToken();
    if (token == null || token.isEmpty) {
      return null;
    }
    try {
      final UserProfileModel profile = await _apiClient.fetchMyProfile(
        jwtToken: token,
      );
      await _authService.persistSession(
        jwtToken: token,
        userId: profile.id,
        profile: profile,
      );
      await _storageService.saveUnitSystem(profile.unitSystem);
      await _storageService.savePreferredWearable(profile.preferredWearable);
      return profile;
    } catch (_) {
      return await _storageService.readUserProfileCache();
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
    await _authService.persistSession(
      jwtToken: token,
      userId: updated.id,
      profile: updated,
    );
    await _storageService.saveUnitSystem(updated.unitSystem);
    await _storageService.savePreferredWearable(updated.preferredWearable);
    return updated;
  }

  Future<void> logout() async {
    await _authService.logoutExplicitly();
  }

  Future<WearableMetricRecord> readCachedWearableTelemetry({
    String defaultSource = 'WHOOP',
  }) {
    return _storageService.readCachedWearableTelemetry(
      defaultSource: defaultSource,
    );
  }

  Future<void> saveCachedWearableTelemetry(WearableMetricRecord record) {
    return _storageService.saveCachedWearableTelemetry(record);
  }

  Future<BiometricRecord?> readCachedBiometrics() {
    return _storageService.readCachedBiometrics();
  }

  Future<void> saveCachedBiometrics(BiometricRecord record) {
    return _storageService.saveCachedBiometrics(record);
  }

  Future<AiGeneratedRoutinePlanModel?> readCachedAiRoutinePlan() {
    return _storageService.readCachedAiRoutinePlan();
  }

  Future<void> saveCachedAiRoutinePlan(AiGeneratedRoutinePlanModel plan) {
    return _storageService.saveCachedAiRoutinePlan(plan);
  }

  Future<List<RoutineTemplateModel>> readCachedRoutineTemplates() {
    return _storageService.readCachedRoutineTemplates();
  }

  Future<void> saveCachedRoutineTemplates(
    List<RoutineTemplateModel> routines,
  ) {
    return _storageService.saveCachedRoutineTemplates(routines);
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

    // Priorizar el registro ya persistido hoy en PostgreSQL (ej. por escaneo de captura o sync previo)
    if (!forceSensorPoll) {
      try {
        final WearableMetricRecord? existingCloud =
            await _apiClient.fetchTodayWearable(jwtToken: token);
        if (existingCloud != null &&
            !(existingCloud.recoveryScore.round() == 62 &&
                existingCloud.sleepEfficiencyPct.round() == 90 &&
                existingCloud.restingHr == 62)) {
          return existingCloud;
        }
      } catch (_) {}
    }

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

    final WearableMetricRecord? fallbackCloud =
        await _apiClient.fetchTodayWearable(jwtToken: token);
    if (fallbackCloud != null &&
        fallbackCloud.recoveryScore.round() == 62 &&
        fallbackCloud.sleepEfficiencyPct.round() == 90 &&
        fallbackCloud.restingHr == 62) {
      return null;
    }
    return fallbackCloud;
  }

  /// Solicita explícitamente permisos de lectura a Health Connect, sincroniza con PostgreSQL
  /// si existen lecturas hoy, o retorna el registro existente hoy junto con el mensaje diagnóstico.
  Future<HealthConnectPollResult> forcePollHealthConnectAndSync({
    String? sourceDevice,
  }) async {
    final String token = await _requireToken();
    final String preferred =
        sourceDevice ?? await _storageService.readPreferredWearable();

    final HealthConnectPollResult poll =
        await _healthConnectService.requestPermissionsAndPollToday(
      preferredSource: preferred,
    );

    if (poll.record != null) {
      final WearableMetricRecord saved = await _apiClient.syncWearableMetrics(
        record: poll.record!,
        jwtToken: token,
      );
      return HealthConnectPollResult(
        record: saved,
        sdkAvailable: poll.sdkAvailable,
        permissionGranted: poll.permissionGranted,
        statusMessage: poll.statusMessage,
      );
    }

    final WearableMetricRecord? cloudRecord =
        await _apiClient.fetchTodayWearable(jwtToken: token);
    final WearableMetricRecord? sanitizedCloud = (cloudRecord != null &&
            cloudRecord.recoveryScore.round() == 62 &&
            cloudRecord.sleepEfficiencyPct.round() == 90 &&
            cloudRecord.restingHr == 62)
        ? null
        : cloudRecord;
    return HealthConnectPollResult(
      record: sanitizedCloud,
      sdkAvailable: poll.sdkAvailable,
      permissionGranted: poll.permissionGranted,
      statusMessage: poll.statusMessage,
    );
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

  /// Escanea una captura de pantalla de WHOOP desde bytes (`POST /api/v1/wearables/scan-whoop`)
  /// y sincroniza las métricas extraídas en PostgreSQL.
  Future<Map<String, dynamic>> scanWhoopScreenshot(
    Uint8List bytes, {
    String sourceDevice = 'WHOOP',
  }) async {
    final String token = await _requireToken();
    return _apiClient.scanWhoopScreenshotBytes(
      bytes: bytes,
      jwtToken: token,
      sourceDevice: sourceDevice,
    );
  }

  /// Escanea una captura de pantalla del wearable seleccionado con Gemini Vision (`POST /api/v1/wearables/scan-screen`)
  /// y sincroniza las métricas extraídas en PostgreSQL.
  Future<WearableMetricRecord> scanWhoopScreenImage(
    File imageFile, {
    String sourceDevice = 'WHOOP',
  }) async {
    final String token = await _requireToken();
    return _apiClient.scanWhoopScreenMetrics(
      imageFile: imageFile,
      jwtToken: token,
      sourceDevice: sourceDevice,
    );
  }

  /// Envía un mensaje al Gemini Coach Personal con el contexto biométrico en vivo.
  Future<AiCoachChatResponseModel> sendAiCoachChat({
    required String message,
    required List<AiCoachChatMessageModel> history,
    required Map<String, dynamic> athleteContext,
  }) async {
    final String token = await _requireToken();
    return _apiClient.sendAiCoachChat(
      message: message,
      history: history,
      athleteContext: athleteContext,
      jwtToken: token,
    );
  }

  Future<BiometricRecord?> loadLatestBiometrics() async {
    final String token = await _requireToken();
    final BiometricRecord? record =
        await _apiClient.fetchLatestBiometrics(jwtToken: token);
    if (record != null) {
      await _storageService.saveCachedBiometrics(record);
    }
    return record;
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

  String _todayYmd() {
    final DateTime now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _formatAmPm(DateTime dt) {
    final int h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final String m = dt.minute.toString().padLeft(2, '0');
    final String suffix = dt.hour < 12 ? 'AM' : 'PM';
    return '${h.toString().padLeft(2, '0')}:$m $suffix';
  }

  Future<HydrationStatusModel> loadTodayHydration({
    double weightKg = 78.0,
    double strainScore = 10.0,
  }) async {
    final String ymd = _todayYmd();
    final int recommendedGoal =
        ((weightKg * 35.0) + (strainScore * 60.0)).round().clamp(2000, 6000);
    final List<Map<String, dynamic>> localRaw =
        await _storageService.readHydrationLogsForDate(ymd);

    try {
      final String? token = await _storageService.readJwtToken();
      if (token != null && token.isNotEmpty) {
        final HydrationStatusModel cloud = await _apiClient.fetchTodayHydration(
          jwtToken: token,
        );
        if (cloud.logs.isNotEmpty || localRaw.isEmpty) {
          await _storageService.saveHydrationLogsForDate(
            ymd,
            cloud.logs.map((HydrationLogEntryModel e) => e.toJson()).toList(),
          );
          return cloud;
        }
      }
    } catch (_) {}

    final List<HydrationLogEntryModel> localEntries =
        localRaw.map(HydrationLogEntryModel.fromJson).toList();
    final int total = localEntries.fold<int>(
      0,
      (int acc, HydrationLogEntryModel item) => acc + item.amountMl,
    );
    return HydrationStatusModel(
      date: ymd,
      totalMl: total,
      recommendedGoalMl: recommendedGoal,
      completionPct:
          ((total / recommendedGoal) * 100.0).clamp(0.0, 150.0),
      logs: localEntries,
    );
  }

  Future<HydrationStatusModel> addWaterIntakeMl({
    required int amountMl,
    double weightKg = 78.0,
    double strainScore = 10.0,
  }) async {
    final String ymd = _todayYmd();
    final DateTime now = DateTime.now();
    final HydrationLogEntryModel newEntry = HydrationLogEntryModel(
      amountMl: amountMl,
      formattedTime: _formatAmPm(now),
      loggedAt: now,
    );

    final List<Map<String, dynamic>> currentRaw =
        await _storageService.readHydrationLogsForDate(ymd);
    final List<Map<String, dynamic>> updatedRaw = <Map<String, dynamic>>[
      ...currentRaw,
      newEntry.toJson(),
    ];
    await _storageService.saveHydrationLogsForDate(ymd, updatedRaw);

    try {
      final String? token = await _storageService.readJwtToken();
      if (token != null && token.isNotEmpty) {
        final HydrationStatusModel synced = await _apiClient.addHydrationLog(
          amountMl: amountMl,
          jwtToken: token,
        );
        if (synced.totalMl >= amountMl) {
          return synced;
        }
      }
    } catch (_) {}

    final int recommendedGoal =
        ((weightKg * 35.0) + (strainScore * 60.0)).round().clamp(2000, 6000);
    final List<HydrationLogEntryModel> entries =
        updatedRaw.map(HydrationLogEntryModel.fromJson).toList();
    final int total = entries.fold<int>(
      0,
      (int acc, HydrationLogEntryModel item) => acc + item.amountMl,
    );
    return HydrationStatusModel(
      date: ymd,
      totalMl: total,
      recommendedGoalMl: recommendedGoal,
      completionPct:
          ((total / recommendedGoal) * 100.0).clamp(0.0, 150.0),
      logs: entries,
    );
  }

  // =========================================================================
  // 3. RUTINAS SEMANALES, ROLLOVER Y ENTRENO ADAPTATIVO EN VIVO
  // =========================================================================

  Future<AiGeneratedRoutinePlanModel> loadCurrentAiRoutine() async {
    final String token = await _requireToken();
    final AiGeneratedRoutinePlanModel plan =
        await _apiClient.fetchCurrentAiRoutine(jwtToken: token);
    if (plan.hasRoutine && plan.days.isNotEmpty) {
      await _storageService.saveCachedAiRoutinePlan(plan);
    }
    return plan;
  }

  Future<AiGeneratedRoutinePlanModel> generateAiRoutine() async {
    final String token = await _requireToken();
    final AiGeneratedRoutinePlanModel plan =
        await _apiClient.generateAiRoutine(jwtToken: token);
    if (plan.hasRoutine && plan.days.isNotEmpty) {
      await _storageService.saveCachedAiRoutinePlan(plan);
    }
    return plan;
  }

  Future<List<RoutineTemplateModel>> loadWeeklyRoutines() async {
    final String token = await _requireToken();
    final List<RoutineTemplateModel> list =
        await _apiClient.fetchRoutines(jwtToken: token);
    if (list.isNotEmpty) {
      await _storageService.saveCachedRoutineTemplates(list);
    }
    return list;
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

  Future<List<SquadLeaderboardEntryModel>> loadSquadsLeaderboard() async {
    final String token = await _requireToken();
    return _apiClient.fetchSquadsLeaderboard(jwtToken: token);
  }

  Future<List<SquadLeaderboardEntryModel>> joinOrCreateSquad({
    required String squadName,
    required String squadTag,
  }) async {
    final String token = await _requireToken();
    return _apiClient.joinOrCreateSquad(
      squadName: squadName,
      squadTag: squadTag,
      jwtToken: token,
    );
  }

  Future<ActiveDuo2v2DuelModel> loadActive2v2Duel({
    String seasonId = '2026-S4',
  }) async {
    final String token = await _requireToken();
    return _apiClient.fetchActive2v2Duel(
      seasonId: seasonId,
      jwtToken: token,
    );
  }

  Future<ActiveDuo2v2DuelModel> invitePartner2v2Duel({
    required String partnerUsername,
    required String duoName,
  }) async {
    final String token = await _requireToken();
    return _apiClient.invitePartner2v2Duel(
      partnerUsername: partnerUsername,
      duoName: duoName,
      jwtToken: token,
    );
  }
}
