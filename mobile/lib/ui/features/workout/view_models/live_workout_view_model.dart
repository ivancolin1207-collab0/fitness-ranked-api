import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/services/ble_heart_rate_service.dart';
import '../../../../data/models/workout_models.dart';
import '../../../../data/repositories/fitness_repository.dart';

class LiveWorkoutViewModel extends ChangeNotifier {
  final FitnessRepository _repository;
  final BleHeartRateService _bleService;
  StreamSubscription<int>? _bleBpmSub;

  LiveWorkoutViewModel({
    required FitnessRepository repository,
    BleHeartRateService? bleService,
  })  : _repository = repository,
        _bleService = bleService ?? BleHeartRateService() {
    _bleService.addListener(_onBleServiceChanged);
    _bleBpmSub = _bleService.heartRateStream.listen((int realBpm) {
      _liveHeartRate = realBpm;
      notifyListeners();
    });
  }

  BleHeartRateService get bleService => _bleService;
  bool get isBleConnected => _bleService.isConnected;
  String? get bleDeviceName => _bleService.connectedDeviceName;

  List<RoutineTemplateModel> _weeklyRoutines = <RoutineTemplateModel>[];
  List<RoutineTemplateModel> get weeklyRoutines => _weeklyRoutines;

  TodayWorkoutPlanModel? _todayPlan;
  TodayWorkoutPlanModel? get todayPlan => _todayPlan;

  RoutineTemplateModel? _selectedRoutine;
  RoutineTemplateModel? get selectedRoutine => _selectedRoutine;

  String? _activeWorkoutId;
  String? get activeWorkoutId => _activeWorkoutId;

  List<WorkoutSetModel> _sets = <WorkoutSetModel>[];
  List<WorkoutSetModel> get sets => _sets;

  String _unitSystem = 'KG';
  String get unitSystem => _unitSystem;

  int _remainingRestSeconds = 0;
  int get remainingRestSeconds => _remainingRestSeconds;

  int _liveHeartRate = 118;
  int get liveHeartRate => _bleService.latestBpm ?? _liveHeartRate;

  int _projectedEloDelta = 0;
  int get projectedEloDelta => _projectedEloDelta;

  double _sessionLbmScore = 0.0;
  double get sessionLbmScore => _sessionLbmScore;

  String _readinessZone = 'YELLOW_MAINTENANCE';
  String get readinessZone => _readinessZone;

  String _geminiRationale =
      'Gemini Coach adaptará las cargas y repeticiones de tus series según tu RPE real y recuperación diaria.';
  String get geminiRationale => _geminiRationale;

  String? _rolloverBanner;
  String? get rolloverBanner => _rolloverBanner;

  bool _isRolloverActive = false;
  bool get isRolloverActive => _isRolloverActive;

  bool _isLoadingPlan = false;
  bool get isLoadingPlan => _isLoadingPlan;

  bool _isStartingWorkout = false;
  bool get isStartingWorkout => _isStartingWorkout;

  bool _isSubmittingSet = false;
  bool get isSubmittingSet => _isSubmittingSet;

  bool _isSavingRoutine = false;
  bool get isSavingRoutine => _isSavingRoutine;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Timer? _restTimer;

  void _onBleServiceChanged() {
    if (_bleService.latestBpm != null) {
      _liveHeartRate = _bleService.latestBpm!;
    }
    notifyListeners();
  }

  WorkoutSetModel? get currentActiveSet {
    for (final WorkoutSetModel s in _sets) {
      if (!s.completed) {
        return s;
      }
    }
    return null;
  }

  Future<void> initializeWorkoutPlan() async {
    _isLoadingPlan = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _unitSystem = await _repository.getPreferredUnitSystem();
      final List<Object> results = await Future.wait<Object>(<Future<Object>>[
        _repository.loadTodayWorkoutPlan(),
        _repository.loadWeeklyRoutines(),
      ]);

      final TodayWorkoutPlanModel plan = results[0] as TodayWorkoutPlanModel;
      final List<RoutineTemplateModel> routines =
          results[1] as List<RoutineTemplateModel>;

      _todayPlan = plan;
      _weeklyRoutines = routines;
      _isRolloverActive = plan.isRollover;
      _rolloverBanner = plan.coachRolloverBanner;
      _selectedRoutine =
          plan.activeRoutine ?? (routines.isNotEmpty ? routines.first : null);

      if (plan.activeWorkout != null) {
        _activeWorkoutId = plan.activeWorkout!.id;
        _sets = plan.activeWorkout!.sets;
        _sessionLbmScore = plan.activeWorkout!.lbmAllometricScore;
        final String? notes = plan.activeWorkout!.aiPrescriptionNotes;
        if (notes != null && notes.isNotEmpty) {
          _geminiRationale = notes;
          if (notes.contains('Recuperación comprometida') ||
              notes.contains('Zona Roja')) {
            _readinessZone = 'RED_DELOAD';
          } else if (notes.contains('Zona Verde')) {
            _readinessZone = 'GREEN_OVERLOAD';
          }
        }
      } else {
        _activeWorkoutId = null;
        _sets = <WorkoutSetModel>[];
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('HttpException: ', '');
    } finally {
      _isLoadingPlan = false;
      notifyListeners();
    }
  }

  void selectRoutineTemplate(RoutineTemplateModel routine) {
    _selectedRoutine = routine;
    notifyListeners();
  }

  Future<void> startSelectedRoutine() async {
    final RoutineTemplateModel? routine = _selectedRoutine;
    if (routine == null) {
      return;
    }

    _isStartingWorkout = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final WorkoutSessionModel session =
          await _repository.startWorkoutFromRoutine(
        routineId: routine.id,
        isRollover: _isRolloverActive &&
            _todayPlan?.activeRoutine?.id == routine.id,
      );
      _activeWorkoutId = session.id;
      _sets = session.sets;
      _sessionLbmScore = session.lbmAllometricScore;
      final String? notes = session.aiPrescriptionNotes;
      if (notes != null && notes.isNotEmpty) {
        _geminiRationale = notes;
        if (notes.contains('Recuperación comprometida') ||
            notes.contains('Zona Roja')) {
          _readinessZone = 'RED_DELOAD';
        } else if (notes.contains('Zona Verde')) {
          _readinessZone = 'GREEN_OVERLOAD';
        } else {
          _readinessZone = 'YELLOW_MAINTENANCE';
        }
      } else {
        _geminiRationale =
            'Sesión "${routine.name}" iniciada con sobrecarga progresiva semanal calculada desde PostgreSQL.';
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('HttpException: ', '');
    } finally {
      _isStartingWorkout = false;
      notifyListeners();
    }
  }

  Future<bool> saveCustomRoutineForDay({
    required int dayOfWeek,
    required String name,
    required String focusGroup,
    required List<Map<String, dynamic>> exercises,
  }) async {
    _isSavingRoutine = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final RoutineTemplateModel saved = await _repository.saveRoutineForDay(
        dayOfWeek: dayOfWeek,
        name: name,
        focusGroup: focusGroup,
        exercises: exercises,
      );
      await initializeWorkoutPlan();
      _selectedRoutine = saved;
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('HttpException: ', '');
      return false;
    } finally {
      _isSavingRoutine = false;
      notifyListeners();
    }
  }

  Future<void> toggleUnitSystem() async {
    _unitSystem = _unitSystem == 'KG' ? 'LB' : 'KG';
    await _repository.setPreferredUnitSystem(_unitSystem);
    notifyListeners();
  }

  double displayWeight(double weightKg) {
    if (_unitSystem == 'LB') {
      return double.parse((weightKg * 2.20462).toStringAsFixed(1));
    }
    return double.parse(weightKg.toStringAsFixed(1));
  }

  String get formattedRestTimer {
    final int mins = _remainingRestSeconds ~/ 60;
    final int secs = _remainingRestSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _startRestCountdown(int seconds) {
    _restTimer?.cancel();
    _remainingRestSeconds = seconds;
    if (!isBleConnected) {
      _liveHeartRate = 154;
    }
    notifyListeners();

    _restTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (_remainingRestSeconds <= 0) {
        timer.cancel();
        if (!isBleConnected) {
          _liveHeartRate = 114;
        }
      } else {
        _remainingRestSeconds--;
        if (!isBleConnected &&
            _liveHeartRate > 112 &&
            _remainingRestSeconds % 4 == 0) {
          _liveHeartRate--;
        }
      }
      notifyListeners();
    });
  }

  Future<void> submitSetBinaryFeedback({
    required WorkoutSetModel targetSet,
    required bool completedBinaryUi,
    required double actualWeightKg,
    required int actualReps,
    required double actualRpe,
  }) async {
    final String? wId = _activeWorkoutId;
    if (wId == null) {
      return;
    }

    _isSubmittingSet = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final SetExecutionFeedbackRequestModel req =
          SetExecutionFeedbackRequestModel(
        exerciseId: targetSet.exerciseId,
        setNumber: targetSet.setNumber,
        completedBinaryUi: completedBinaryUi,
        actualWeightKg: actualWeightKg,
        actualReps: actualReps,
        actualRpe: actualRpe,
      );

      final SetExecutionFeedbackResponseModel res =
          await _repository.registerSetAndRecalculate(
        workoutId: wId,
        feedback: req,
      );

      final Map<int, PrescribedSetModel> updatesBySetNum =
          <int, PrescribedSetModel>{
        for (final PrescribedSetModel item
            in res.geminiPrescription.updatedSets)
          item.setNumber: item,
      };

      _sets = _sets.map((WorkoutSetModel s) {
        if (s.id == targetSet.id) {
          return s.copyWith(
            actualWeightKg: actualWeightKg,
            actualReps: actualReps,
            actualRpe: actualRpe,
            estimated1RmKg: res.estimated1RmKg,
            completed: true,
          );
        }
        if (!s.completed &&
            s.exerciseId == targetSet.exerciseId &&
            updatesBySetNum.containsKey(s.setNumber)) {
          final PrescribedSetModel upd = updatesBySetNum[s.setNumber]!;
          return s.copyWith(
            prescribedWeightKg: upd.prescribedWeightKg,
            prescribedReps: upd.prescribedReps,
            prescribedRpe: upd.prescribedRpe,
            aiRecalculated: true,
          );
        }
        return s;
      }).toList();

      _projectedEloDelta = res.projectedEloDelta;
      _sessionLbmScore = res.sessionLbmAllometricScore;
      _readinessZone = res.geminiPrescription.readinessZone;
      _geminiRationale = res.geminiPrescription.adjustmentRationale;

      final int nextRest = res.geminiPrescription.updatedSets.isNotEmpty
          ? res.geminiPrescription.updatedSets.first.restSeconds
          : 150;
      _startRestCountdown(nextRest);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('HttpException: ', '');
    } finally {
      _isSubmittingSet = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _bleBpmSub?.cancel();
    _bleService.removeListener(_onBleServiceChanged);
    _bleService.dispose();
    super.dispose();
  }
}
