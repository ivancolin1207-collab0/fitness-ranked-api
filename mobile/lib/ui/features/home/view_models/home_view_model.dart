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

  BiometricRecord? _biometrics;
  BiometricRecord? get biometrics => _biometrics;

  List<BiometricRecord> _biometricsHistory = <BiometricRecord>[];
  List<BiometricRecord> get biometricsHistory => _biometricsHistory;

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

      _wearable = results[0] as WearableMetricRecord?;
      _biometrics = results[1] as BiometricRecord?;
      _biometricsHistory =
          (results[2] as List<BiometricRecord>?) ?? <BiometricRecord>[];
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
}
