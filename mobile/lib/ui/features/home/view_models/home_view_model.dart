import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:image_picker/image_picker.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/ble_heart_rate_service.dart';
import '../../../../core/services/wearable_service.dart';
import '../../../../data/models/auth_models.dart';
import '../../../../data/models/biometric_models.dart';
import '../../../../data/repositories/fitness_repository.dart';
import '../../../../data/services/health_connect_service.dart';

typedef ReadinessViewModel = HomeViewModel;

class HomeViewModel extends ChangeNotifier {
  final FitnessRepository _repository;
  final ImagePicker _imagePicker;

  HomeViewModel({
    required FitnessRepository repository,
    ImagePicker? imagePicker,
  })  : _repository = repository,
        _imagePicker = imagePicker ?? ImagePicker();

  WearableMetricRecord? _wearable;
  WearableMetricRecord? get wearable => _wearable;

  bool hasWhoopData = false;
  bool isLockedByScan = false;
  double? recoveryScore;
  double? strainScore;
  double? sleepPct;
  double? stressScore;
  String? stressCategory;
  double? sleepHours;
  double? hrvMs;
  int? restingHr;

  bool whoopCloudLinked = false;
  bool whoopOAuthConfigured = false;
  String? whoopAuthorizeUrl;
  bool _isSyncingWhoopCloud = false;
  bool get isSyncingWhoopCloud => _isSyncingWhoopCloud;

  double? recovery;
  double? strain;
  double? sleep;
  double? stress;

  double? whoopRecovery;
  double? whoopStrain;
  double? whoopSleep;
  double? whoopStress;
  String? whoopStressCategory;
  double? whoopSleepHours;

  /// Recuperación efectiva real hoy (`null` si el usuario no ha sincronizado su banda hoy o si es `<= 0`).
  /// PROHIBIDO devolver `0` o `0.0`: `<= 0` significa `SIN DATOS` (`--`), jamás Zona Roja.
  double? get effectiveRecovery {
    if (!hasWhoopData) {
      return null;
    }
    final double? rec = whoopRecovery ?? recoveryScore ?? _wearable?.recoveryScore;
    if (rec == null || rec < 1.0) {
      return null;
    }
    return rec;
  }

  /// Porcentaje de sueño efectivo hoy (`null` si es `<= 0`). PROHIBIDO devolver `0%`.
  double? get effectiveSleepPct {
    if (!hasWhoopData) {
      return null;
    }
    final double? slp = whoopSleep ?? sleepPct ?? _wearable?.sleepEfficiencyPct;
    if (slp == null || slp < 1.0) {
      return null;
    }
    return slp;
  }

  /// Regla de negocio: Zona Roja (`-15%` carga) SOLO se activa si `recoveryScore >= 1 && recoveryScore < 34`.
  bool get isRedZoneDeload {
    final double? rec = effectiveRecovery;
    return rec != null && rec >= 1.0 && rec < 34.0;
  }

  /// Semáforo dinámico de Whoop recalculado en cada cambio de `whoopRecovery`.
  Color get recoveryColor {
    final double? rec = effectiveRecovery;
    if (rec == null) return const Color(0xFF6B7280); // SIN SINCRONIZAR HOY
    if (rec >= 67.0) return const Color(0xFF10B981); // VERDE ÓPTIMO
    if (rec >= 34.0) return const Color(0xFFF59E0B); // AMARILLO MANTENIMIENTO
    return const Color(0xFFEF4444); // ROJO RECUPERACIÓN BAJA (1% - 33%)
  }

  String get recoveryStatusText {
    final double? rec = effectiveRecovery;
    if (rec == null) return 'SIN SINCRONIZAR HOY';
    if (rec >= 67.0) return 'ZONA VERDE • RENDIMIENTO ÓPTIMO';
    if (rec >= 34.0) return 'ZONA AMARILLA • MANTENIMIENTO';
    return 'ZONA ROJA • DESCANSO ACTIVO';
  }

  String get whoopZoneLabel => recoveryStatusText;

  BiometricRecord? _biometrics;
  BiometricRecord? get biometrics => _biometrics;

  List<BiometricRecord> _biometricsHistory = <BiometricRecord>[];
  List<BiometricRecord> get biometricsHistory => _biometricsHistory;

  HydrationStatusModel? _hydration;
  HydrationStatusModel? get hydration => _hydration;

  String _unitSystem = 'KG';
  String get unitSystem => _unitSystem;

  String _preferredWearable = 'WHOOP';
  String get preferredWearable => _preferredWearable;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSyncingWearable = false;
  bool get isSyncingWearable => _isSyncingWearable;

  bool _isScanningOcr = false;
  bool get isScanningOcr => _isScanningOcr;

  bool _isScanningWhoop = false;
  bool get isScanningWhoop => _isScanningWhoop;

  bool _isSavingBiometrics = false;
  bool get isSavingBiometrics => _isSavingBiometrics;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _statusBanner;
  String? get statusBanner => _statusBanner;

  void _clearWearableMetricsInMemory() {
    _wearable = null;
    hasWhoopData = false;
    isLockedByScan = false;
    recoveryScore = null;
    strainScore = null;
    sleepPct = null;
    stressScore = null;
    stressCategory = null;
    sleepHours = null;
    hrvMs = null;
    restingHr = null;
    recovery = null;
    strain = null;
    sleep = null;
    stress = null;
    whoopRecovery = null;
    whoopStrain = null;
    whoopSleep = null;
    whoopStress = null;
    whoopStressCategory = null;
    whoopSleepHours = null;
  }

  /// Purga el estado en memoria de biometría, hidratación y telemetría al cambiar de usuario o cerrar sesión.
  void resetForUserSwitch() {
    _clearWearableMetricsInMemory();
    _biometrics = null;
    _biometricsHistory = <BiometricRecord>[];
    _hydration = null;
    _errorMessage = null;
    _statusBanner = null;
    whoopCloudLinked = false;
    whoopAuthorizeUrl = null;
    notifyListeners();
  }

  Future<void> initializeDashboard() async {
    _errorMessage = null;

    try {
      _unitSystem = await _repository.getPreferredUnitSystem();
      _preferredWearable = await _repository.getPreferredWearable();
      isLockedByScan = await _repository.isLockedByWhoopScanToday();

      // 1. Carga local aislada por usuario y día (`readiness_${uid}_${today}`)
      final WearableMetricRecord? cachedWearable =
          await _repository.readCachedWearableTelemetry();
      if (cachedWearable != null) {
        _wearable = cachedWearable;
        setMetrics(
          cachedWearable,
          persistToCache: false,
          isFromScanOrManual: isLockedByScan,
        );
      } else {
        _clearWearableMetricsInMemory();
      }

      final BiometricRecord? cachedBio =
          await _repository.readCachedBiometrics();
      _biometrics = cachedBio;

      _isLoading = false;
      notifyListeners();

      // 2. Sincronización asíncrona no bloqueante con PostgreSQL (Render)
      final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
        _repository
            .syncTodayWearableData(sourceDevice: _preferredWearable)
            .catchError((_) => null),
        _repository.loadLatestBiometrics().catchError((_) => null),
        _repository
            .loadBiometricsHistory()
            .catchError((_) => <BiometricRecord>[]),
        _repository.getCurrentUserProfileCache().catchError((_) => null),
      ]);

      final WearableMetricRecord? loadedWearable =
          results[0] as WearableMetricRecord?;
      if (loadedWearable != null) {
        setMetrics(loadedWearable, isFromScanOrManual: false);
      }

      final BiometricRecord? loadedBio = results[1] as BiometricRecord?;
      if (loadedBio != null) {
        _biometrics = loadedBio;
      }

      final List<BiometricRecord> historyList =
          (results[2] as List<BiometricRecord>?) ?? <BiometricRecord>[];
      _biometricsHistory = historyList;

      final UserProfileModel? profile = results[3] as UserProfileModel?;
      BleHeartRateService.instance.updateAthletePhysiology(
        restingHr: (_wearable?.restingHr ?? 0) >= 25 ? _wearable!.restingHr : null,
        isMale: (profile?.sex ?? 'male').toLowerCase() != 'female',
      );

      // 3. Verificar estado OAuth de WHOOP Cloud y auto-sincronizar si está vinculado
      unawaited(_checkAndAutoSyncWhoopCloudIfLinked());

      // 4. Si aún no hay telemetría hoy en PostgreSQL y no está bloqueada por escaneo, realizar lectura de Health Connect
      if (loadedWearable == null && !hasWhoopData && !isLockedByScan) {
        try {
          final HealthConnectPollResult hcResult =
              await _repository.forcePollHealthConnectAndSync(
            sourceDevice: _preferredWearable,
          );
          if (hcResult.record != null) {
            setMetrics(hcResult.record!, isFromScanOrManual: false);
            _statusBanner = hcResult.statusMessage;
          }
        } catch (_) {
          // Falla silenciosa en el auto-poll inicial; el botón Forzar Sync sigue disponible.
        }
      }

      final double? realWeight = _biometrics?.weightKg ?? profile?.weightKg;
      final double? realStrain =
          hasWhoopData ? (_wearable?.strainScore ?? strainScore) : null;

      _hydration = await _repository.loadTodayHydration(
        weightKg: realWeight,
        strainScore: realStrain,
      );
    } catch (e) {
      final String clean = ApiErrorSanitizer.sanitizeRawErrorString(e);
      if (clean != ApiErrorSanitizer.cloudReconnectingMessage) {
        _errorMessage = clean;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _checkAndAutoSyncWhoopCloudIfLinked() async {
    try {
      final WearableService svc = WearableService();
      final WhoopOAuthStatusModel? status = await svc.fetchWhoopOAuthStatus();
      if (status == null) {
        return;
      }
      whoopCloudLinked = status.linked;
      whoopOAuthConfigured = status.oauthConfigured;
      whoopAuthorizeUrl = status.authorizeUrl;
      notifyListeners();

      if (whoopCloudLinked) {
        final Map<String, dynamic> synced = await svc.syncWhoopCloudNow();
        applyScanResponse(synced, sourceDevice: 'WHOOP');
      }
    } catch (_) {
      // No bloquea el arranque si el usuario aún no ha vinculado WHOOP Cloud.
    }
  }

  /// Sincroniza directamente desde la API oficial de WHOOP Cloud (`developer.whoop.com`)
  /// si el usuario ya vinculó su cuenta OAuth 2.0, o devuelve la URL de autorización OAuth.
  Future<Map<String, dynamic>> syncOrLinkWhoopCloud() async {
    _isSyncingWhoopCloud = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final WearableService svc = WearableService();
      final WhoopOAuthStatusModel? status = await svc.fetchWhoopOAuthStatus();
      whoopCloudLinked = status?.linked == true;
      whoopOAuthConfigured = status?.oauthConfigured == true;
      whoopAuthorizeUrl = status?.authorizeUrl;

      if (whoopCloudLinked) {
        final Map<String, dynamic> synced = await svc.syncWhoopCloudNow();
        applyScanResponse(synced, sourceDevice: 'WHOOP');
        _statusBanner =
            'WHOOP Cloud API sincronizada automáticamente (developer.whoop.com)';
        return <String, dynamic>{
          'action': 'synced',
          'response': synced,
        };
      }

      if (whoopAuthorizeUrl != null && whoopAuthorizeUrl!.isNotEmpty) {
        final bool opened =
            await svc.openExternalBrowserUrl(whoopAuthorizeUrl!);
        return <String, dynamic>{
          'action': 'oauth_launched',
          'opened': opened,
          'authorize_url': whoopAuthorizeUrl,
          'oauth_configured': whoopOAuthConfigured,
        };
      }

      return <String, dynamic>{
        'action': 'unconfigured',
        'message':
            'Configura WHOOP_CLIENT_ID y WHOOP_CLIENT_SECRET en Render (developer.whoop.com) para habilitar OAuth 2.0 directo en la nube.',
      };
    } finally {
      _isSyncingWhoopCloud = false;
      notifyListeners();
    }
  }

  Future<void> toggleUnitSystem() async {
    _unitSystem = _unitSystem == 'KG' ? 'LB' : 'KG';
    await _repository.setPreferredUnitSystem(_unitSystem);
    notifyListeners();
  }

  Future<void> setPreferredWearableSource(String source) async {
    _preferredWearable = source;
    await _repository.setPreferredWearable(source);
    if (_wearable != null) {
      _wearable = _wearable!.copyWith(sourceDevice: source);
    }
    notifyListeners();
    await forceSyncWearable();
  }

  Future<void> forceSyncWearable({bool interactive = true}) async {
    _isSyncingWearable = true;
    _errorMessage = null;
    _statusBanner = null;
    notifyListeners();

    try {
      final HealthConnectPollResult result =
          await _repository.forcePollHealthConnectAndSync(
        sourceDevice: _preferredWearable,
        interactive: interactive,
      );
      if (result.record != null) {
        setMetrics(result.record!, isFromScanOrManual: false);
      }
      _statusBanner = result.statusMessage;
    } catch (e) {
      final String clean = ApiErrorSanitizer.sanitizeRawErrorString(e);
      if (clean != ApiErrorSanitizer.cloudReconnectingMessage) {
        _errorMessage = clean;
      }
    } finally {
      _isSyncingWearable = false;
      notifyListeners();
    }
  }

  Future<bool> saveDirectWearableTelemetry(WearableMetricRecord record) async {
    _isSyncingWearable = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final WearableMetricRecord saved =
          await _repository.pushWearableRecord(record, lockTodayScan: true);
      _wearable = saved.copyWith(
        sourceDevice: _preferredWearable,
        sleepEfficiencyPct: record.sleepEfficiencyPct,
        whoopStressLevel: record.whoopStressLevel,
        stressCategory: record.stressCategory,
        whoopHealthMetricsInRange: record.whoopHealthMetricsInRange,
        huaweiStressScore: record.huaweiStressScore,
        huaweiTruSleepScore: record.huaweiTruSleepScore,
        huaweiVo2Max: record.huaweiVo2Max,
        samsungEnergyScore: record.samsungEnergyScore,
        samsungBiaMusclePct: record.samsungBiaMusclePct,
        samsungBiaFatPct: record.samsungBiaFatPct,
        appleMoveKcal: record.appleMoveKcal,
        appleExerciseMinutes: record.appleExerciseMinutes,
        appleStandHours: record.appleStandHours,
      );
      setMetrics(_wearable!, isFromScanOrManual: true);
      final double recVal = _wearable!.recoveryScore;
      final bool isLowReadiness = (recVal >= 1.0 && recVal < 34.0) ||
          (_wearable!.sleepEfficiencyPct >= 1.0 &&
              _wearable!.sleepEfficiencyPct < 70.0) ||
          (_preferredWearable == 'WHOOP' && _wearable!.whoopStressLevel >= 2.0);
      _statusBanner = isLowReadiness
          ? 'Recuperación comprometida (${recVal.toStringAsFixed(0)}%) y estrés elevado. Redujimos el volumen prescrito para evitar fatiga del SNC.'
          : 'Telemetría $_preferredWearable guardada en PostgreSQL (Readiness: ${recVal.toStringAsFixed(0)}% | Sueño: ${_wearable!.sleepEfficiencyPct.toStringAsFixed(0)}%)';
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('HttpException: ', '');
      return false;
    } finally {
      _isSyncingWearable = false;
      notifyListeners();
    }
  }

  double formatMass(double kgValue) {
    if (_unitSystem == 'LB') {
      return double.parse((kgValue * 2.20462).toStringAsFixed(1));
    }
    return double.parse(kgValue.toStringAsFixed(1));
  }

  /// Actualiza de forma reactiva las métricas del wearable activo y notifica a la UI.
  /// PROHIBIDO que lecturas parciales de Health Connect (`isFromScanOrManual == false`)
  /// asignen `0%` a `sleepPct` o `0%` a `recoveryScore` o sobrescriban una captura escaneada hoy (`isLockedByScan`).
  void setMetrics(
    WearableMetricRecord updated, {
    bool persistToCache = true,
    bool isFromScanOrManual = false,
  }) {
    if (isLockedByScan && !isFromScanOrManual) {
      if ((hrvMs == null || hrvMs! <= 0) && updated.hrvMs > 0) {
        hrvMs = updated.hrvMs;
      }
      if ((restingHr == null || restingHr! <= 0) && updated.restingHr > 0) {
        restingHr = updated.restingHr;
        BleHeartRateService.instance
            .updateAthletePhysiology(restingHr: updated.restingHr);
      }
      notifyListeners();
      return;
    }

    final double? validRec = updated.recoveryScore >= 1.0
        ? updated.recoveryScore
        : ((whoopRecovery != null && whoopRecovery! >= 1.0)
            ? whoopRecovery
            : null);
    final double? validSleep = updated.sleepEfficiencyPct >= 1.0
        ? updated.sleepEfficiencyPct
        : ((whoopSleep != null && whoopSleep! >= 1.0) ? whoopSleep : null);
    final double? validStrain = updated.strainScore > 0.0
        ? updated.strainScore
        : ((whoopStrain != null && whoopStrain! > 0.0) ? whoopStrain : null);
    final double? validStress = updated.whoopStressLevel > 0.0
        ? updated.whoopStressLevel
        : ((whoopStress != null && whoopStress! > 0.0) ? whoopStress : null);
    final double? validSleepH = updated.sleepHours > 0.0
        ? updated.sleepHours
        : ((whoopSleepHours != null && whoopSleepHours! > 0.0)
            ? whoopSleepHours
            : null);

    hasWhoopData =
        validRec != null || validSleep != null || validStrain != null;

    if (isFromScanOrManual && (validRec != null || validSleep != null)) {
      isLockedByScan = true;
      unawaited(_repository.saveWhoopScanLockForToday(true));
    }

    recoveryScore = validRec;
    strainScore = validStrain;
    sleepPct = validSleep;
    stressScore = validStress;
    sleepHours = validSleepH;

    if (updated.hrvMs > 0) {
      hrvMs = updated.hrvMs;
    }
    if (updated.restingHr > 0) {
      restingHr = updated.restingHr;
      BleHeartRateService.instance
          .updateAthletePhysiology(restingHr: updated.restingHr);
    }

    final String resolvedCategory = (updated.stressCategory != null &&
            updated.stressCategory!.trim().isNotEmpty &&
            updated.stressCategory!.trim().toUpperCase() != 'SIN DATOS' &&
            updated.stressCategory!.trim().toUpperCase() != 'SIN DATO')
        ? updated.stressCategory!.trim().toUpperCase()
        : (validStress != null
            ? (validStress >= 2.0
                ? 'ALTO'
                : (validStress >= 1.0 ? 'MEDIO' : 'BAJO'))
            : (stressCategory ?? 'SIN DATOS'));
    stressCategory = resolvedCategory;

    recovery = validRec;
    strain = validStrain;
    sleep = validSleep;
    stress = validStress;
    whoopRecovery = validRec;
    whoopStrain = validStrain;
    whoopSleep = validSleep;
    whoopStress = validStress;
    whoopSleepHours = validSleepH;
    whoopStressCategory = resolvedCategory;

    _wearable = updated.copyWith(
      recoveryScore: validRec ?? 0.0,
      sleepEfficiencyPct: validSleep ?? 0.0,
      strainScore: validStrain ?? 0.0,
      sleepHours: validSleepH ?? 0.0,
      whoopStressLevel: validStress ?? 0.0,
      stressCategory: resolvedCategory,
      hrvMs: (hrvMs != null && hrvMs! > 0) ? hrvMs : updated.hrvMs,
      restingHr:
          (restingHr != null && restingHr! > 0) ? restingHr : updated.restingHr,
    );
    if (persistToCache && hasWhoopData) {
      unawaited(_repository.saveCachedWearableTelemetry(_wearable!));
    }
    notifyListeners();
  }

  /// Asigna directamente los datos extraídos del escaneo de WHOOP al ViewModel,
  /// activa `hasWhoopData = true` y `isLockedByScan = true`, persiste en `readiness_${userId}_${today}` y dispara `notifyListeners()`.
  void setWhoopData({
    required bool hasData,
    required double recovery,
    required double strain,
    required double sleep,
    required double stressLevel,
    required String stressCategory,
    required double sleepHours,
    double? hrvMs,
    int? restingHr,
    int? healthMetricsInRange,
    String? sourceDevice,
  }) {
    final String cleanCat = stressCategory.trim().isNotEmpty
        ? stressCategory.trim().toUpperCase()
        : (stressLevel >= 2.0
            ? 'ALTO'
            : (stressLevel >= 1.0 ? 'MEDIO' : 'BAJO'));

    final double resolvedHrv = (hrvMs != null && hrvMs > 0)
        ? hrvMs
        : (this.hrvMs ?? _wearable?.hrvMs ?? 0.0);
    final int resolvedRhr = (restingHr != null && restingHr > 0)
        ? restingHr
        : (this.restingHr ?? _wearable?.restingHr ?? 0);

    final double? validRec = recovery >= 1.0 ? recovery : whoopRecovery;
    final double? validSleep = sleep >= 1.0 ? sleep : whoopSleep;

    hasWhoopData = hasData;
    isLockedByScan = true;
    unawaited(_repository.saveWhoopScanLockForToday(true));

    recoveryScore = validRec;
    strainScore = strain;
    sleepPct = validSleep;
    stressScore = stressLevel;
    this.stressCategory = cleanCat;
    this.sleepHours = sleepHours;
    if (resolvedHrv > 0) {
      this.hrvMs = resolvedHrv;
    }
    if (resolvedRhr > 0) {
      this.restingHr = resolvedRhr;
      BleHeartRateService.instance
          .updateAthletePhysiology(restingHr: resolvedRhr);
    }

    this.recovery = validRec;
    this.strain = strain;
    this.sleep = validSleep;
    stress = stressLevel;

    whoopRecovery = validRec;
    whoopStrain = strain;
    whoopSleep = validSleep;
    whoopStress = stressLevel;
    whoopStressCategory = cleanCat;
    whoopSleepHours = sleepHours;

    final DateTime now = DateTime.now();
    final WearableMetricRecord base = _wearable ??
        WearableMetricRecord(
          date: now,
          sourceDevice: sourceDevice ?? _preferredWearable,
          hrvMs: resolvedHrv,
          restingHr: resolvedRhr,
          avgHr: 0,
          maxHr: 0,
          sleepHours: sleepHours,
          sleepEfficiencyPct: validSleep ?? 0.0,
          strainScore: strain,
          recoveryScore: validRec ?? 0.0,
          whoopStressLevel: stressLevel,
          stressCategory: cleanCat,
          whoopHealthMetricsInRange: healthMetricsInRange ?? 5,
        );

    _wearable = base.copyWith(
      sourceDevice: sourceDevice ?? _preferredWearable,
      hrvMs: resolvedHrv > 0 ? resolvedHrv : base.hrvMs,
      restingHr: resolvedRhr > 0 ? resolvedRhr : base.restingHr,
      sleepEfficiencyPct: validSleep ?? base.sleepEfficiencyPct,
      sleepHours: sleepHours,
      recoveryScore: validRec ?? base.recoveryScore,
      strainScore: strain,
      whoopStressLevel: stressLevel,
      stressCategory: cleanCat,
      whoopHealthMetricsInRange:
          healthMetricsInRange ?? (base.whoopHealthMetricsInRange > 0 ? base.whoopHealthMetricsInRange : 5),
    );
    unawaited(_repository.saveCachedWearableTelemetry(_wearable!));

    _errorMessage = null;
    _statusBanner =
        'Telemetría actualizada: Recuperación ${(validRec ?? 0).toStringAsFixed(0)}% | Sueño ${(validSleep ?? 0).toStringAsFixed(0)}% | Strain ${strain.toStringAsFixed(1)}';
    notifyListeners();
  }

  /// Sobrescribe las variables reactivas que alimentan los 3 anillos circulares
  /// (`whoopRecovery`, `whoopStrain`, `whoopSleep`, `whoopStress`), recalcula
  /// automáticamente la etiqueta de zona y dispara `notifyListeners()`.
  void updateFromWhoopScan({
    required double recoveryScore,
    required double strainScore,
    required double sleepScore,
    double? stressScore,
    String? stressCategory,
    double? sleepHours,
    double? hrvMs,
    int? restingHr,
    int? healthMetricsInRange,
    String? sourceDevice,
  }) {
    final double resolvedStress =
        stressScore ?? whoopStress ?? _wearable?.whoopStressLevel ?? 0.0;
    final double resolvedSleepHours =
        sleepHours ?? whoopSleepHours ?? _wearable?.sleepHours ?? 0.0;
    final String resolvedCategory =
        (stressCategory != null && stressCategory.trim().isNotEmpty)
            ? stressCategory.trim().toUpperCase()
            : (resolvedStress >= 2.0
                ? 'ALTO'
                : (resolvedStress >= 1.0 ? 'MEDIO' : 'BAJO'));

    setWhoopData(
      hasData: true,
      recovery: recoveryScore,
      strain: strainScore,
      sleep: sleepScore,
      stressLevel: resolvedStress,
      stressCategory: resolvedCategory,
      sleepHours: resolvedSleepHours,
      hrvMs: hrvMs,
      restingHr: restingHr,
      healthMetricsInRange: healthMetricsInRange,
      sourceDevice: sourceDevice,
    );
  }

  /// Sobrescribe de inmediato TODAS las variables en memoria y `readiness_${userId}_${today}`
  /// con la respuesta JSON de Gemini Vision (`{status, data:{...}}` o JSON plano).
  void applyScanResponse(
    Map<String, dynamic> response, {
    String? sourceDevice,
  }) {
    final Map<String, dynamic> data = (response['data'] is Map)
        ? Map<String, dynamic>.from(response['data'] as Map)
        : response;

    double? tryNum(List<String> keys) {
      for (final String k in keys) {
        final Object? v = data[k] ?? response[k];
        if (v is num) {
          return v.toDouble();
        }
        if (v is String) {
          final double? parsed = double.tryParse(v);
          if (parsed != null) {
            return parsed;
          }
        }
      }
      return null;
    }

    final double rec =
        tryNum(<String>['recovery_score']) ?? whoopRecovery ?? 0.0;
    final double str =
        tryNum(<String>['strain_score']) ?? whoopStrain ?? 0.0;
    final double slp = tryNum(<String>[
          'sleep_pct',
          'sleep_performance_pct',
          'sleep_efficiency_pct',
        ]) ??
        whoopSleep ??
        0.0;
    final double stl =
        tryNum(<String>['stress_level', 'whoop_stress_level']) ??
            whoopStress ??
            0.0;
    final double slh =
        tryNum(<String>['sleep_hours']) ?? whoopSleepHours ?? 0.0;
    final double? scannedHrv = tryNum(<String>['hrv_ms']);
    final int? scannedRhr =
        tryNum(<String>['resting_hr', 'rhr_bpm'])?.round();
    final int? scannedHealthOk = tryNum(<String>[
      'health_monitor_metrics_ok',
      'whoop_health_metrics_in_range',
    ])?.round();
    final String? cat =
        (data['stress_category'] ?? response['stress_category']) as String?;

    updateFromWhoopScan(
      recoveryScore: rec,
      strainScore: str,
      sleepScore: slp,
      stressScore: stl,
      stressCategory: (cat != null && cat.trim().isNotEmpty) ? cat : null,
      sleepHours: slh,
      hrvMs: (scannedHrv != null && scannedHrv > 0) ? scannedHrv : null,
      restingHr: (scannedRhr != null && scannedRhr > 0) ? scannedRhr : null,
      healthMetricsInRange: scannedHealthOk,
      sourceDevice: sourceDevice,
    );
    _statusBanner =
        'Banda sincronizada: Recuperación ${rec.toStringAsFixed(0)}% | Esfuerzo ${str.toStringAsFixed(1)}';
    notifyListeners();
  }

  /// Envía los bytes comprimidos de la captura de WHOOP a Gemini Vision (`POST /api/v1/wearables/scan-whoop`),
  /// actualiza el estado reactivo con `applyScanResponse` y devuelve el mapa de resultados.
  Future<Map<String, dynamic>?> scanWhoopScreenshotBytes(
    Uint8List bytes, {
    String? sourceDevice,
  }) async {
    _errorMessage = null;
    _statusBanner = null;
    final String targetSource = sourceDevice ?? _preferredWearable;

    _isScanningWhoop = true;
    notifyListeners();

    try {
      final Map<String, dynamic> result =
          await _repository.scanWhoopScreenshot(
        bytes,
        sourceDevice: targetSource,
      );
      _preferredWearable = targetSource;
      await _repository.setPreferredWearable(targetSource);

      applyScanResponse(result, sourceDevice: targetSource);

      final UserProfileModel? profile =
          await _repository.getCurrentUserProfileCache();
      _hydration = await _repository.loadTodayHydration(
        weightKg: _biometrics?.weightKg ?? profile?.weightKg,
        strainScore: _wearable?.strainScore ?? strainScore,
      );
      return result;
    } catch (e) {
      _errorMessage =
          'Error al escanear captura de $targetSource: ${e.toString().replaceFirst("HttpException: ", "")}';
      return null;
    } finally {
      _isScanningWhoop = false;
      notifyListeners();
    }
  }

  /// Escanea una captura de pantalla del wearable activo (`POST /api/v1/wearables/scan-whoop`)
  /// con compresión obligatoria (`maxWidth: 1080, imageQuality: 80`), bloquea `isLockedByScan = true`
  /// y devuelve el registro extraído para pre-llenar el modal de confirmación estilo Fitdays.
  Future<WearableMetricRecord?> scanWhoopScreenshot(
    ImageSource source, {
    String? sourceDevice,
  }) async {
    _errorMessage = null;
    _statusBanner = null;
    final String targetSource = sourceDevice ?? _preferredWearable;

    final XFile? picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1080,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (picked == null) {
      return null;
    }

    _isScanningWhoop = true;
    notifyListeners();

    try {
      final File imageFile = File(picked.path);
      final WearableMetricRecord scanned =
          await _repository.scanWhoopScreenImage(
        imageFile,
        sourceDevice: targetSource,
      );
      _preferredWearable = targetSource;
      await _repository.setPreferredWearable(targetSource);
      setMetrics(
        scanned.copyWith(sourceDevice: targetSource),
        isFromScanOrManual: true,
      );
      await _repository.clearCachedAiRoutinePlan();
      final UserProfileModel? profile =
          await _repository.getCurrentUserProfileCache();
      _hydration = await _repository.loadTodayHydration(
        weightKg: _biometrics?.weightKg ?? profile?.weightKg,
        strainScore: _wearable?.strainScore,
      );
      _statusBanner =
          'Gemini Vision extrajo tu captura de $targetSource. Revisa y confirma para guardar en Render.';
      return _wearable;
    } catch (e) {
      _errorMessage =
          'Error al escanear captura de $targetSource: ${e.toString().replaceFirst("HttpException: ", "")}';
      return null;
    } finally {
      _isScanningWhoop = false;
      notifyListeners();
    }
  }

  /// Sube el screenshot comprimido de Fitdays (`1080x1920`, `imageQuality: 75`) y devuelve los campos
  /// extraídos por Gemini Vision para autocompletar el formulario modal antes de confirmar.
  Future<FitdaysExtractedMetricsModel?> scanFitdaysForFormPrefill(
    ImageSource source,
  ) async {
    _errorMessage = null;
    _statusBanner = null;

    final XFile? picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1080,
      maxHeight: 1920,
      imageQuality: 75,
    );
    if (picked == null) {
      return null;
    }

    _isScanningOcr = true;
    notifyListeners();

    try {
      final File imageFile = File(picked.path);
      final FitdaysExtractedMetricsModel extracted =
          await _repository.extractFitdaysOcrForForm(imageFile);
      _statusBanner =
          'Gemini Vision extrajo el reporte Fitdays. Revisa y confirma para guardar.';
      return extracted;
    } catch (e) {
      _errorMessage =
          'Error al escanear reporte con Gemini Vision: ${e.toString().replaceFirst("HttpException: ", "")}';
      return null;
    } finally {
      _isScanningOcr = false;
      notifyListeners();
    }
  }

  /// Guarda las métricas de bioimpedancia (manuales o revisadas tras OCR) en Render PostgreSQL
  /// e invalida la caché de rutina para regenerar cargas con el nuevo LBM.
  Future<bool> saveBiometricsRecord(
    FitdaysExtractedMetricsModel payload,
  ) async {
    _isSavingBiometrics = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final BiometricRecord saved = await _repository.saveBiometrics(payload);
      _biometrics = saved;
      _biometricsHistory = await _repository.loadBiometricsHistory();
      await _repository.clearCachedAiRoutinePlan();
      _hydration = await _repository.loadTodayHydration(
        weightKg: saved.weightKg,
        strainScore: hasWhoopData ? _wearable?.strainScore : null,
      );
      _statusBanner =
          'Composición corporal guardada en Render (LBM: ${saved.leanBodyMassKg} kg)';
      return true;
    } catch (e) {
      _errorMessage =
          'No se pudo guardar en base de datos: ${e.toString().replaceFirst("HttpException: ", "")}';
      return false;
    } finally {
      _isSavingBiometrics = false;
      notifyListeners();
    }
  }

  Future<void> addWaterIntake(int amountMl) async {
    _errorMessage = null;
    try {
      final UserProfileModel? profile =
          await _repository.getCurrentUserProfileCache();
      _hydration = await _repository.addWaterIntakeMl(
        amountMl: amountMl,
        weightKg: _biometrics?.weightKg ?? profile?.weightKg,
        strainScore: hasWhoopData ? _wearable?.strainScore : null,
      );
      final double liters = _hydration!.totalMl / 1000.0;
      _statusBanner =
          '+$amountMl ml registrados • Hidratación hoy: ${liters.toStringAsFixed(2)} L (${_hydration!.completionPct.toStringAsFixed(0)}% de tu meta)';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('HttpException: ', '');
      notifyListeners();
    }
  }

  String get aiCoachAthletePrescriptionSummary {
    final WearableMetricRecord? w = hasWhoopData ? _wearable : null;
    final double? rec = effectiveRecovery;
    final double? lbm = _biometrics?.leanBodyMassKg;
    final String lbmText =
        lbm != null ? 'LBM ${lbm.toStringAsFixed(1)} kg' : 'LBM del perfil';
    final int waterMl = _hydration?.totalMl ?? 0;
    final int? goalMl = _hydration?.recommendedGoalMl;
    final String goalText = goalMl != null
        ? '${(goalMl / 1000.0).toStringAsFixed(1)} L'
        : '-- L';

    if (w == null || rec == null) {
      return 'Sin telemetría de $_preferredWearable sincronizada hoy (--). Escanea tu captura del día o registra métricas para ajustar el volumen y RPE dinámico sobre tu $lbmText. Hidratación actual: ${(waterMl / 1000.0).toStringAsFixed(2)} L / $goalText.';
    }

    if (rec < 34.0 ||
        (w.sleepEfficiencyPct > 0 && w.sleepEfficiencyPct < 70.0) ||
        (w.sleepHours > 0 && w.sleepHours < 6.0)) {
      return 'Readiness en Zona Roja (${rec.toStringAsFixed(0)}%) en $_preferredWearable. Gemini Coach aplica descarga activa (-15% carga, RPE 6.5-7.0). Hidratación actual: ${(waterMl / 1000.0).toStringAsFixed(2)} L / $goalText.';
    }
    if (waterMl < 1000 && goalMl != null) {
      return 'Alerta de Hidratación ($waterMl ml / $goalMl ml): registra al menos +500 ml antes de tus series principales para sostener tu fuerza alométrica ($lbmText).';
    }
    if (rec >= 67.0) {
      return 'Zona Verde ($_preferredWearable ${rec.toStringAsFixed(0)}%) + Hidratación ${(waterMl / 1000.0).toStringAsFixed(2)} L. Gemini Coach habilita sobrecarga progresiva (+4% carga @ RPE 8.5) escalada a tu $lbmText.';
    }
    return 'Zona Amarilla ($_preferredWearable ${rec.toStringAsFixed(0)}%). Mantén cargas objetivo (100% base @ RPE 7.5-8.0) con hidratación constante (${(waterMl / 1000.0).toStringAsFixed(2)} L / $goalText).';
  }
}
