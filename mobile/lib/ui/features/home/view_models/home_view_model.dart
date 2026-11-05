import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
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
  double recoveryScore = 0.0;
  double strainScore = 0.0;
  double sleepPct = 0.0;
  double stressScore = 0.0;
  String stressCategory = 'MEDIO';
  double sleepHours = 7.7;

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

  String get whoopZoneLabel {
    final double rec = hasWhoopData
        ? recoveryScore
        : (whoopRecovery ?? _wearable?.recoveryScore ?? 47.0);
    if (rec >= 67.0) {
      return 'ZONA VERDE • SOBRECARGA';
    }
    if (rec >= 34.0) {
      return 'ZONA AMARILLA • MANTENIMIENTO';
    }
    return 'ZONA ROJA • DELOAD (-20%)';
  }

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

  Future<void> initializeDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _unitSystem = await _repository.getPreferredUnitSystem();
      _preferredWearable = await _repository.getPreferredWearable();

      final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
        _repository.syncTodayWearableData(sourceDevice: _preferredWearable),
        _repository.loadLatestBiometrics(),
        _repository.loadBiometricsHistory(),
      ]);

      final WearableMetricRecord? loadedWearable =
          results[0] as WearableMetricRecord?;
      if (loadedWearable != null &&
          loadedWearable.recoveryScore.round() == 62 &&
          loadedWearable.sleepEfficiencyPct.round() == 90 &&
          loadedWearable.restingHr == 62) {
        _wearable = null;
      } else {
        _wearable = loadedWearable;
      }

      if (_wearable != null) {
        hasWhoopData = true;
        recoveryScore = _wearable!.recoveryScore;
        strainScore = _wearable!.strainScore;
        sleepPct = _wearable!.sleepEfficiencyPct;
        stressScore = _wearable!.whoopStressLevel;
        sleepHours = _wearable!.sleepHours;
        stressCategory = _wearable!.whoopStressLevel >= 2.0
            ? 'ALTO'
            : (_wearable!.whoopStressLevel >= 1.0 ? 'MEDIO' : 'BAJO');
        recovery = _wearable!.recoveryScore;
        strain = _wearable!.strainScore;
        sleep = _wearable!.sleepEfficiencyPct;
        stress = _wearable!.whoopStressLevel;
        whoopRecovery = _wearable!.recoveryScore;
        whoopStrain = _wearable!.strainScore;
        whoopSleep = _wearable!.sleepEfficiencyPct;
        whoopStress = _wearable!.whoopStressLevel;
        whoopSleepHours = _wearable!.sleepHours;
        whoopStressCategory = stressCategory;
      } else {
        hasWhoopData = false;
      }

      final BiometricRecord? loadedBio = results[1] as BiometricRecord?;
      if (loadedBio != null &&
          loadedBio.weightKg == 78.4 &&
          (loadedBio.fatPercentage == 14.6 || loadedBio.fatPercentage == 14.8)) {
        _biometrics = null;
      } else {
        _biometrics = loadedBio;
      }

      _biometricsHistory =
          ((results[2] as List<BiometricRecord>?) ?? <BiometricRecord>[])
              .where(
                (BiometricRecord b) =>
                    !(b.weightKg == 78.4 &&
                        (b.fatPercentage == 14.6 || b.fatPercentage == 14.8)),
              )
              .toList();
      _hydration = await _repository.loadTodayHydration(
        weightKg: _biometrics?.weightKg ?? 78.0,
        strainScore: _wearable?.strainScore ?? 10.0,
      );
      if (_wearable == null) {
        _statusBanner = 'Sin telemetría sincronizada en Health Connect hoy';
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('HttpException: ', '');
    } finally {
      _isLoading = false;
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

  Future<void> forceSyncWearable() async {
    _isSyncingWearable = true;
    _errorMessage = null;
    _statusBanner = null;
    notifyListeners();

    try {
      final HealthConnectPollResult result =
          await _repository.forcePollHealthConnectAndSync(
        sourceDevice: _preferredWearable,
      );
      _wearable = result.record;
      if (_wearable != null) {
        setMetrics(_wearable!);
      }
      _statusBanner = result.statusMessage;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('HttpException: ', '');
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
          await _repository.pushWearableRecord(record);
      _wearable = saved.copyWith(
        sourceDevice: _preferredWearable,
        sleepEfficiencyPct: record.sleepEfficiencyPct,
        whoopStressLevel: record.whoopStressLevel,
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
      setMetrics(_wearable!);
      final bool isLowReadiness = _wearable!.recoveryScore < 40.0 ||
          _wearable!.sleepEfficiencyPct < 70.0 ||
          (_preferredWearable == 'WHOOP' && _wearable!.whoopStressLevel >= 2.0);
      _statusBanner = isLowReadiness
          ? 'Recuperación comprometida (${_wearable!.recoveryScore.toStringAsFixed(0)}%) y estrés elevado. Redujimos el volumen prescrito para evitar fatiga del SNC.'
          : 'Telemetría $_preferredWearable guardada en PostgreSQL (Readiness: ${_wearable!.recoveryScore.toStringAsFixed(0)}%)';
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
  void setMetrics(WearableMetricRecord updated) {
    hasWhoopData = true;
    recoveryScore = updated.recoveryScore;
    strainScore = updated.strainScore;
    sleepPct = updated.sleepEfficiencyPct;
    stressScore = updated.whoopStressLevel;
    sleepHours = updated.sleepHours;
    stressCategory = updated.whoopStressLevel >= 2.0
        ? 'ALTO'
        : (updated.whoopStressLevel >= 1.0 ? 'MEDIO' : 'BAJO');

    recovery = updated.recoveryScore;
    strain = updated.strainScore;
    sleep = updated.sleepEfficiencyPct;
    stress = updated.whoopStressLevel;
    whoopRecovery = updated.recoveryScore;
    whoopStrain = updated.strainScore;
    whoopSleep = updated.sleepEfficiencyPct;
    whoopStress = updated.whoopStressLevel;
    whoopSleepHours = updated.sleepHours;
    whoopStressCategory = stressCategory;
    _wearable = updated;
    notifyListeners();
  }

  /// Asigna directamente los datos extraídos del escaneo de WHOOP al ViewModel,
  /// activa `hasWhoopData = true` y dispara `notifyListeners()` para reconstruir la UI al instante.
  void setWhoopData({
    required bool hasData,
    required double recovery,
    required double strain,
    required double sleep,
    required double stressLevel,
    required String stressCategory,
    required double sleepHours,
    int? hrvMs,
    int? restingHr,
    int? healthMetricsInRange,
    String? sourceDevice,
  }) {
    final String cleanCat = stressCategory.trim().isNotEmpty
        ? stressCategory.trim().toUpperCase()
        : (stressLevel >= 2.0 ? 'ALTO' : (stressLevel >= 1.0 ? 'MEDIO' : 'BAJO'));

    hasWhoopData = hasData;
    recoveryScore = recovery;
    strainScore = strain;
    sleepPct = sleep;
    stressScore = stressLevel;
    this.stressCategory = cleanCat;
    this.sleepHours = sleepHours;

    this.recovery = recovery;
    this.strain = strain;
    this.sleep = sleep;
    stress = stressLevel;

    whoopRecovery = recovery;
    whoopStrain = strain;
    whoopSleep = sleep;
    whoopStress = stressLevel;
    whoopStressCategory = cleanCat;
    whoopSleepHours = sleepHours;

    final DateTime now = DateTime.now();
    final WearableMetricRecord base = _wearable ??
        WearableMetricRecord(
          date: now,
          sourceDevice: sourceDevice ?? _preferredWearable,
          hrvMs: (hrvMs ?? 56).toDouble(),
          restingHr: restingHr ?? 58,
          avgHr: 68,
          maxHr: 155,
          sleepHours: sleepHours,
          sleepEfficiencyPct: sleep,
          strainScore: strain,
          recoveryScore: recovery,
          whoopStressLevel: stressLevel,
          whoopHealthMetricsInRange: healthMetricsInRange ?? 5,
        );

    _wearable = base.copyWith(
      sourceDevice: sourceDevice ?? _preferredWearable,
      sleepEfficiencyPct: sleep,
      sleepHours: sleepHours,
      recoveryScore: recovery,
      strainScore: strain,
      whoopStressLevel: stressLevel,
      whoopHealthMetricsInRange:
          healthMetricsInRange ?? base.whoopHealthMetricsInRange,
    );

    _errorMessage = null;
    _statusBanner =
        'Telemetría actualizada: Recuperación ${recovery.toStringAsFixed(0)}% | Strain ${strain.toStringAsFixed(1)}';
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
    int? hrvMs,
    int? restingHr,
    int? healthMetricsInRange,
    String? sourceDevice,
  }) {
    final double resolvedStress =
        stressScore ?? whoopStress ?? _wearable?.whoopStressLevel ?? 1.8;
    final double resolvedSleepHours = sleepHours ??
        whoopSleepHours ??
        _wearable?.sleepHours ??
        double.parse((sleepScore * 0.09625).toStringAsFixed(1));
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

  /// Envía los bytes de la captura de pantalla de WHOOP a Gemini Vision (`POST /api/v1/wearables/scan-whoop`),
  /// actualiza el estado reactivo con `updateFromWhoopScan` y devuelve el mapa de resultados.
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

      final double recScore =
          ((result['recovery_score'] ?? 47.0) as num).toDouble();
      final double strScore =
          ((result['strain_score'] ?? 7.4) as num).toDouble();
      final double slpScore =
          ((result['sleep_pct'] ?? result['sleep_performance_pct'] ?? 80.0)
                  as num)
              .toDouble();
      final double strLevel =
          ((result['stress_level'] ?? result['whoop_stress_level'] ?? 1.8)
                  as num)
              .toDouble();
      final String? strCat = result['stress_category'] as String?;
      final double? slpHours = (result['sleep_hours'] as num?)?.toDouble();

      updateFromWhoopScan(
        recoveryScore: recScore,
        strainScore: strScore,
        sleepScore: slpScore,
        stressScore: strLevel,
        stressCategory: strCat,
        sleepHours: slpHours,
        hrvMs: (result['hrv_ms'] as num?)?.toInt(),
        restingHr: (result['rhr_bpm'] as num?)?.toInt(),
        healthMetricsInRange:
            (result['health_monitor_metrics_ok'] as num?)?.toInt(),
        sourceDevice: targetSource,
      );

      _hydration = await _repository.loadTodayHydration(
        weightKg: _biometrics?.weightKg ?? 78.0,
        strainScore: _wearable?.strainScore ?? strScore,
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

  /// Escanea una captura de pantalla del wearable activo (`POST /api/v1/wearables/scan-screen`)
  /// y actualiza los diales en pantalla de forma reactiva e inmediata (`setMetrics` + `notifyListeners()`).
  Future<WearableMetricRecord?> scanWhoopScreenshot(
    ImageSource source, {
    String? sourceDevice,
  }) async {
    _errorMessage = null;
    _statusBanner = null;
    final String targetSource = sourceDevice ?? _preferredWearable;

    final XFile? picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1600,
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
      setMetrics(scanned.copyWith(sourceDevice: targetSource));
      _hydration = await _repository.loadTodayHydration(
        weightKg: _biometrics?.weightKg ?? 78.0,
        strainScore: _wearable?.strainScore ?? 10.0,
      );
      if (targetSource == 'WHOOP') {
        _statusBanner =
            'Captura WHOOP sincronizada: ${_wearable!.sleepEfficiencyPct.round()}% Sueño • ${_wearable!.recoveryScore.round()}% Recuperación • Strain ${_wearable!.strainScore.toStringAsFixed(1)} • Estrés ${_wearable!.whoopStressLevel.toStringAsFixed(1)}';
      } else if (targetSource == 'HUAWEI_GT') {
        _statusBanner =
            'Captura Huawei sincronizada: TruSleep ${_wearable!.huaweiTruSleepScore} pts • Estrés ${_wearable!.huaweiStressScore}/100 • VO2Max ${_wearable!.huaweiVo2Max.toStringAsFixed(1)}';
      } else if (targetSource == 'SAMSUNG_WATCH') {
        _statusBanner =
            'Captura Samsung sincronizada: Energy Score ${_wearable!.samsungEnergyScore} • Sueño ${_wearable!.sleepHours.toStringAsFixed(1)} h';
      } else {
        _statusBanner =
            'Captura $targetSource sincronizada (Recuperación: ${_wearable!.recoveryScore.round()}%)';
      }
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

  /// Sube el screenshot de Fitdays y devuelve los campos extraídos por Gemini Vision
  /// para autocompletar el formulario modal antes de confirmar.
  Future<FitdaysExtractedMetricsModel?> scanFitdaysForFormPrefill(
    ImageSource source,
  ) async {
    _errorMessage = null;
    _statusBanner = null;

    final XFile? picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1600,
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

  /// Guarda las métricas de bioimpedancia (manuales o revisadas tras OCR) en Render PostgreSQL.
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
      _hydration = await _repository.addWaterIntakeMl(
        amountMl: amountMl,
        weightKg: _biometrics?.weightKg ?? 78.0,
        strainScore: _wearable?.strainScore ?? 10.0,
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
    final double rec = _wearable?.recoveryScore ?? 78.0;
    final double sleepH = _wearable?.sleepHours ?? 7.4;
    final double sleepEff = _wearable?.sleepEfficiencyPct ?? 85.0;
    final double lbm = _biometrics?.leanBodyMassKg ?? 65.0;
    final int waterMl = _hydration?.totalMl ?? 0;
    final int goalMl = _hydration?.recommendedGoalMl ?? 2800;

    if (rec < 40.0 || sleepEff < 70.0 || sleepH < 6.0) {
      return 'Readiness en Zona Roja (${rec.toStringAsFixed(0)}%) y sueño/estrés comprometidos en $_preferredWearable. Gemini Coach reduce volumen (-15% a -20%) y limita a RPE 6.5 (enfoque movilidad/técnica). Hidratación actual: ${(waterMl / 1000.0).toStringAsFixed(2)} L / ${(goalMl / 1000.0).toStringAsFixed(1)} L.';
    }
    if (waterMl < 1000) {
      return 'Alerta de Hidratación ($waterMl ml / $goalMl ml): registra al menos +500 ml antes de tus series principales para sostener tu fuerza alométrica (LBM ${lbm.toStringAsFixed(1)} kg) sin fatiga prematura.';
    }
    if (rec >= 80.0) {
      return 'Zona Verde ($_preferredWearable ${rec.toStringAsFixed(0)}%) + Hidratación óptima (${(waterMl / 1000.0).toStringAsFixed(2)} L). Gemini Coach habilita sobrecarga progresiva (+2.5 kg) escalada a tu LBM (${lbm.toStringAsFixed(1)} kg).';
    }
    return 'Zona Amarilla ($_preferredWearable ${rec.toStringAsFixed(0)}%). Mantén cargas objetivo @ RPE 8.0 con hidratación constante (${(waterMl / 1000.0).toStringAsFixed(2)} L / ${(goalMl / 1000.0).toStringAsFixed(1)} L).';
  }
}
