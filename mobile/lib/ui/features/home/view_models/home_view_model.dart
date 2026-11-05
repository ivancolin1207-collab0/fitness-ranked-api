import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../data/models/biometric_models.dart';
import '../../../../data/repositories/fitness_repository.dart';
import '../../../../data/services/health_connect_service.dart';

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

  double? recovery;
  double? strain;
  double? sleep;
  double? stress;

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
          loadedWearable.recoveryScore == 62.0 &&
          loadedWearable.sleepEfficiencyPct == 90.0 &&
          loadedWearable.restingHr == 62) {
        _wearable = null;
      } else {
        _wearable = loadedWearable;
      }

      if (_wearable != null) {
        recovery = _wearable!.recoveryScore;
        strain = _wearable!.strainScore;
        sleep = _wearable!.sleepEfficiencyPct;
        stress = _wearable!.whoopStressLevel;
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
    recovery = updated.recoveryScore;
    strain = updated.strainScore;
    sleep = updated.sleepEfficiencyPct;
    stress = updated.whoopStressLevel;
    _wearable = updated;
    notifyListeners();
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
