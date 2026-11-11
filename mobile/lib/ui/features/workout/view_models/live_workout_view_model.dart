import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/ble_heart_rate_service.dart';
import '../../../../data/models/auth_models.dart';
import '../../../../data/models/biometric_models.dart';
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

  String _athleteGender = 'male';
  String get athleteGender => _athleteGender;

  double? _lbmKg;
  double? get lbmKg => _lbmKg;

  double? _weightKg;
  double? get weightKg => _weightKg;

  double? _recoveryScore;
  double? get recoveryScore => _recoveryScore;

  String? _biometricSignature;
  String? get biometricSignature => _biometricSignature;

  bool _requiresBiometrics = false;
  bool get requiresBiometrics => _requiresBiometrics;

  List<String> _missingBiometricFields = <String>[];
  List<String> get missingBiometricFields => _missingBiometricFields;

  /// Purga inmediatamente el estado en memoria cuando se cierra sesión o se cambia de cuenta
  /// para evitar que un usuario nuevo vea rutinas, series o cargas del usuario anterior.
  void resetForUserSwitch() {
    _restTimer?.cancel();
    _remainingRestSeconds = 0;
    _weeklyRoutines = <RoutineTemplateModel>[];
    _todayPlan = null;
    _selectedRoutine = null;
    _activeWorkoutId = null;
    _sets = <WorkoutSetModel>[];
    _selectedExerciseIndex = 0;
    _selectedSetId = null;
    _errorMessage = null;
    _isRolloverActive = false;
    _rolloverBanner = null;
    _projectedEloDelta = 0;
    _sessionLbmScore = 0.0;
    _lbmKg = null;
    _weightKg = null;
    _recoveryScore = null;
    _biometricSignature = null;
    _requiresBiometrics = false;
    _missingBiometricFields = <String>[];
    _liveHeartRate = null;
    _readinessZone = 'SIN TELEMETRÍA HOY • CARGA BASE';
    notifyListeners();
  }

  Future<void> setAthleteGender(String gender) async {
    _athleteGender = gender.toLowerCase().contains('fem') ? 'female' : 'male';
    notifyListeners();
    await _repository.setAthleteGender(_athleteGender);
  }

  int _remainingRestSeconds = 0;
  int get remainingRestSeconds => _remainingRestSeconds;

  int? _liveHeartRate;
  int? get liveHeartRate =>
      _bleService.isConnected ? (_bleService.latestBpm ?? _liveHeartRate) : null;

  int _projectedEloDelta = 0;
  int get projectedEloDelta => _projectedEloDelta;

  double _sessionLbmScore = 0.0;
  double get sessionLbmScore => _sessionLbmScore;

  String _readinessZone = 'SIN TELEMETRÍA HOY • CARGA BASE';
  String get readinessZone => _readinessZone;

  String _geminiRationale =
      'Gemini Coach adapta tus 5 días × 6 ejercicios y pesos exactos a tu sexo biológico, masa magra (LBM) y recuperación diaria.';
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

  bool _isGeneratingAiRoutine = false;
  bool get isGeneratingAiRoutine => _isGeneratingAiRoutine;

  String _aiRoutineTitle = '';
  String get aiRoutineTitle => _aiRoutineTitle;

  String _aiWeeklyFocus = '';
  String get aiWeeklyFocus => _aiWeeklyFocus;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Timer? _restTimer;

  int _selectedExerciseIndex = 0;
  int get selectedExerciseIndex => _selectedExerciseIndex;

  String? _selectedSetId;
  String? get selectedSetId => _selectedSetId;

  void _onBleServiceChanged() {
    if (_bleService.isConnected && _bleService.latestBpm != null) {
      _liveHeartRate = _bleService.latestBpm;
    } else if (!_bleService.isConnected) {
      _liveHeartRate = null;
    }
    notifyListeners();
  }

  void _applyReadinessZoneFromRecovery(double? rec) {
    _recoveryScore = rec;
    if (rec == null) {
      _readinessZone = 'SIN TELEMETRÍA HOY • CARGA BASE (1.0x)';
    } else if (rec < 34.0) {
      _readinessZone = 'ZONA ROJA (${rec.toStringAsFixed(0)}%) • DESCARGA -15%';
    } else if (rec >= 67.0) {
      _readinessZone =
          'ZONA VERDE (${rec.toStringAsFixed(0)}%) • SOBRECARGA +4%';
    } else {
      _readinessZone =
          'ZONA AMARILLA (${rec.toStringAsFixed(0)}%) • MANTENIMIENTO';
    }
  }

  /// Lista de los ejercicios (6 por día) disponibles en la rutina activa,
  /// sin ningún bloqueo lineal.
  List<RoutineExerciseItemModel> get activeDayExercises {
    final List<RoutineExerciseItemModel> routineEx =
        _selectedRoutine?.exercises ?? const <RoutineExerciseItemModel>[];
    if (routineEx.isNotEmpty) {
      return routineEx;
    }
    final Map<String, RoutineExerciseItemModel> distinct =
        <String, RoutineExerciseItemModel>{};
    int order = 1;
    for (final WorkoutSetModel s in _sets) {
      final String k = s.exerciseName.toLowerCase().trim();
      distinct.putIfAbsent(
        k,
        () => RoutineExerciseItemModel(
          id: s.exerciseId,
          exerciseId: s.exerciseId,
          exerciseName: s.exerciseName,
          exerciseKey: s.exerciseKey,
          muscleGroup: 'General',
          displayOrder: order++,
          targetSets: _sets
              .where((WorkoutSetModel item) =>
                  item.exerciseName.toLowerCase().trim() == k)
              .length,
          targetReps: s.prescribedReps,
          targetRepsRange: '${s.prescribedReps}',
          targetWeightKg: s.prescribedWeightKg,
          targetRpe: s.prescribedRpe,
          restSeconds: s.restSeconds,
          tempo: s.tempo,
          coachingCue: s.coachingCue,
        ),
      );
    }
    return distinct.values.toList();
  }

  bool _matchesExercise(WorkoutSetModel s, RoutineExerciseItemModel ex) {
    final String sName = s.exerciseName.toLowerCase().trim();
    final String exName = ex.exerciseName.toLowerCase().trim();
    if (sName == exName || s.exerciseId == ex.exerciseId) {
      return true;
    }
    if (s.exerciseKey.isNotEmpty &&
        ex.exerciseKey.isNotEmpty &&
        s.exerciseKey.toLowerCase().trim() ==
            ex.exerciseKey.toLowerCase().trim()) {
      return true;
    }
    return false;
  }

  List<WorkoutSetModel> setsForExercise(int exerciseIndex) {
    final List<RoutineExerciseItemModel> exercises = activeDayExercises;
    if (exercises.isEmpty) {
      return _sets;
    }
    final int safeIdx = exerciseIndex.clamp(0, exercises.length - 1);
    final RoutineExerciseItemModel targetEx = exercises[safeIdx];
    return _sets
        .where((WorkoutSetModel s) => _matchesExercise(s, targetEx))
        .toList();
  }

  bool isExerciseCompleted(int exerciseIndex) {
    final List<WorkoutSetModel> exSets = setsForExercise(exerciseIndex);
    return exSets.isNotEmpty && exSets.every((WorkoutSetModel s) => s.completed);
  }

  void selectExercise(int index) {
    final List<RoutineExerciseItemModel> exercises = activeDayExercises;
    if (exercises.isEmpty) {
      return;
    }
    _selectedExerciseIndex = index.clamp(0, exercises.length - 1);
    final List<WorkoutSetModel> exSets = setsForExercise(_selectedExerciseIndex);
    if (exSets.isNotEmpty) {
      WorkoutSetModel? firstPending;
      for (final WorkoutSetModel s in exSets) {
        if (!s.completed) {
          firstPending = s;
          break;
        }
      }
      _selectedSetId = (firstPending ?? exSets.last).id;
    } else {
      _selectedSetId = null;
    }
    notifyListeners();
  }

  void selectSet(WorkoutSetModel set) {
    _selectedSetId = set.id;
    final List<RoutineExerciseItemModel> exercises = activeDayExercises;
    for (int i = 0; i < exercises.length; i++) {
      if (_matchesExercise(set, exercises[i])) {
        _selectedExerciseIndex = i;
        break;
      }
    }
    notifyListeners();
  }

  WorkoutSetModel? get currentActiveSet {
    if (_sets.isEmpty) {
      return null;
    }
    if (_selectedSetId != null) {
      for (final WorkoutSetModel s in _sets) {
        if (s.id == _selectedSetId) {
          return s;
        }
      }
    }
    final List<WorkoutSetModel> exSets = setsForExercise(_selectedExerciseIndex);
    if (exSets.isNotEmpty) {
      for (final WorkoutSetModel s in exSets) {
        if (!s.completed) {
          return s;
        }
      }
      return exSets.last;
    }
    for (final WorkoutSetModel s in _sets) {
      if (!s.completed) {
        return s;
      }
    }
    return _sets.first;
  }

  void _syncSetsWithSelectedRoutine({
    List<WorkoutSetModel>? incomingSets,
    bool resetSelection = false,
  }) {
    final List<WorkoutSetModel> sourceSets =
        _enrichSetsWithRoutineMetadata(incomingSets ?? _sets);
    final RoutineTemplateModel? routine = _selectedRoutine;
    if (routine == null || routine.exercises.isEmpty) {
      _sets = sourceSets;
      return;
    }

    final List<WorkoutSetModel> merged = <WorkoutSetModel>[];
    for (int i = 0; i < routine.exercises.length; i++) {
      final RoutineExerciseItemModel ex = routine.exercises[i];
      final List<WorkoutSetModel> existingForEx = sourceSets
          .where((WorkoutSetModel s) => _matchesExercise(s, ex))
          .toList();

      if (existingForEx.isNotEmpty) {
        merged.addAll(existingForEx);
      } else {
        final int totalSets = ex.targetSets > 0 ? ex.targetSets : 3;
        for (int setNum = 1; setNum <= totalSets; setNum++) {
          merged.add(
            WorkoutSetModel(
              id: 'routine_${routine.dayOfWeek}_ex_${i + 1}_s_$setNum',
              exerciseId: ex.exerciseId.isNotEmpty
                  ? ex.exerciseId
                  : 'routine_${routine.dayOfWeek}_ex_${i + 1}',
              exerciseName: ex.exerciseName,
              exerciseKey: ex.exerciseKey,
              setNumber: setNum,
              prescribedWeightKg: ex.targetWeightKg,
              prescribedReps: ex.targetReps,
              prescribedRpe: ex.targetRpe,
              restSeconds: ex.restSeconds,
              tempo: ex.tempo,
              coachingCue: ex.coachingCue,
              completed: false,
            ),
          );
        }
      }
    }

    _sets = merged;
    _activeWorkoutId ??= 'local_session_day_${routine.dayOfWeek}';

    if (resetSelection ||
        _selectedExerciseIndex >= routine.exercises.length) {
      _selectedExerciseIndex = 0;
      _selectedSetId = null;
    }
    final List<WorkoutSetModel> activeExSets =
        setsForExercise(_selectedExerciseIndex);
    if (activeExSets.isNotEmpty &&
        (_selectedSetId == null ||
            !activeExSets.any((WorkoutSetModel s) => s.id == _selectedSetId))) {
      WorkoutSetModel? pending;
      for (final WorkoutSetModel s in activeExSets) {
        if (!s.completed) {
          pending = s;
          break;
        }
      }
      _selectedSetId = (pending ?? activeExSets.first).id;
    }
  }

  List<WorkoutSetModel> _enrichSetsWithRoutineMetadata(
    List<WorkoutSetModel> rawSets,
  ) {
    final Map<String, RoutineExerciseItemModel> byName =
        <String, RoutineExerciseItemModel>{};
    for (final RoutineTemplateModel r in _weeklyRoutines) {
      for (final RoutineExerciseItemModel ex in r.exercises) {
        byName[ex.exerciseName.toLowerCase().trim()] = ex;
      }
    }
    return rawSets.map((WorkoutSetModel s) {
      final RoutineExerciseItemModel? match =
          byName[s.exerciseName.toLowerCase().trim()];
      if (match == null) {
        return s;
      }
      return s.copyWith(
        exerciseKey: match.exerciseKey,
        restSeconds: match.restSeconds,
        tempo: match.tempo,
        coachingCue: match.coachingCue,
      );
    }).toList();
  }

  void updateActiveSetPrescribedWeight(
    WorkoutSetModel targetSet,
    double weightInDisplayedUnit,
  ) {
    final double weightKg = _unitSystem == 'LB'
        ? double.parse((weightInDisplayedUnit / 2.20462).toStringAsFixed(2))
        : double.parse(weightInDisplayedUnit.toStringAsFixed(2));
    _sets = _sets.map((WorkoutSetModel s) {
      if (s.id == targetSet.id) {
        return s.copyWith(prescribedWeightKg: weightKg);
      }
      return s;
    }).toList();
    notifyListeners();
  }

  double _computeBoerLbm({
    required String sex,
    required double weightKg,
    required double heightCm,
  }) {
    final double raw = sex == 'female'
        ? (0.252 * weightKg) + (0.473 * heightCm) - 48.3
        : (0.407 * weightKg) + (0.267 * heightCm) - 19.2;
    return double.parse(
      raw.clamp(weightKg * 0.42, weightKg * 0.94).toStringAsFixed(2),
    );
  }

  Future<void> _resolveUserBiometricsBaseline() async {
    final UserProfileModel? profile =
        await _repository.getCurrentUserProfileCache();

    if (profile != null) {
      final bool isFem = profile.sex.toLowerCase() == 'female' ||
          profile.biologicalSex.toUpperCase() == 'FEMALE';
      _athleteGender = isFem ? 'female' : 'male';
      await _repository.setAthleteGender(_athleteGender);
      _weightKg = profile.weightKg;
      _lbmKg = profile.lbmKg;
      _biometricSignature = profile.biometricSignature;
    } else {
      _athleteGender = await _repository.getAthleteGender();
    }

    try {
      final BiometricRecord? cachedBio =
          await _repository.readCachedBiometrics() ??
              await _repository.loadLatestBiometrics();
      if (cachedBio != null && cachedBio.weightKg > 25) {
        _weightKg = cachedBio.weightKg;
        if (cachedBio.leanBodyMassKg > 15) {
          _lbmKg = cachedBio.leanBodyMassKg;
        } else if (cachedBio.fatPercentage > 0) {
          _lbmKg = double.parse(
            (cachedBio.weightKg * (1.0 - (cachedBio.fatPercentage / 100.0)))
                .toStringAsFixed(2),
          );
        }
      }
    } catch (_) {}

    if (_lbmKg == null &&
        _weightKg != null &&
        profile?.heightCm != null &&
        profile!.heightCm! > 100) {
      _lbmKg = _computeBoerLbm(
        sex: _athleteGender,
        weightKg: _weightKg!,
        heightCm: profile.heightCm!,
      );
    }

    if (_weightKg != null && _lbmKg != null) {
      _biometricSignature =
          '${_athleteGender}_${_weightKg!.round()}_${_lbmKg!.round()}';
    }

    try {
      final WearableMetricRecord? todayWearable =
          await _repository.readCachedWearableTelemetry();
      _applyReadinessZoneFromRecovery(todayWearable?.recoveryScore);
    } catch (_) {
      _applyReadinessZoneFromRecovery(null);
    }
  }

  void _applyAiPlanToState(
    AiGeneratedRoutinePlanModel plan, {
    bool resetSelection = false,
  }) {
    if (plan.sex != null && plan.sex!.isNotEmpty) {
      _athleteGender =
          plan.sex!.toLowerCase().contains('fem') ? 'female' : 'male';
    }
    if (plan.weightKg != null) {
      _weightKg = plan.weightKg;
    }
    if (plan.lbmKg != null) {
      _lbmKg = plan.lbmKg;
    }
    if (plan.biometricSignature != null &&
        plan.biometricSignature!.isNotEmpty) {
      _biometricSignature = plan.biometricSignature;
    }
    if (plan.recoveryScore != null) {
      _applyReadinessZoneFromRecovery(plan.recoveryScore);
    }

    _weeklyRoutines = plan.days;
    _aiRoutineTitle = plan.routineName;
    _aiWeeklyFocus = plan.weeklyFocus;
    final String lbmLabel =
        _lbmKg != null ? '${_lbmKg!.toStringAsFixed(1)} kg LBM' : 'LBM real';
    _geminiRationale =
        '${plan.routineName} • ${plan.weeklyFocus} ($lbmLabel).';

    if (_weeklyRoutines.isNotEmpty) {
      final int preferredDay =
          _selectedRoutine?.dayOfWeek ?? DateTime.now().weekday.clamp(1, 5);
      RoutineTemplateModel? matchedDay;
      for (final RoutineTemplateModel r in _weeklyRoutines) {
        if (r.dayOfWeek == preferredDay) {
          matchedDay = r;
          break;
        }
      }
      _selectedRoutine = matchedDay ?? _weeklyRoutines.first;
      if (resetSelection) {
        _sets = <WorkoutSetModel>[];
      }
      _syncSetsWithSelectedRoutine(resetSelection: resetSelection);
    }
  }

  Future<void> initializeWorkoutPlan({bool forceRefresh = false}) async {
    _errorMessage = null;

    try {
      _unitSystem = await _repository.getPreferredUnitSystem();
      await _resolveUserBiometricsBaseline();

      if (forceRefresh) {
        await _repository.clearCachedAiRoutinePlan();
      }

      // 1. Carga instantánea desde caché local aislada `routine_${userId}` solo si coincide la firma biométrica
      AiGeneratedRoutinePlanModel? cachedPlan =
          forceRefresh ? null : await _repository.readCachedAiRoutinePlan();

      if (cachedPlan != null &&
          _biometricSignature != null &&
          cachedPlan.biometricSignature != null &&
          cachedPlan.biometricSignature != _biometricSignature) {
        await _repository.clearCachedAiRoutinePlan();
        cachedPlan = null;
      }

      if (cachedPlan != null &&
          cachedPlan.hasRoutine &&
          cachedPlan.days.length >= 5) {
        _requiresBiometrics = false;
        _missingBiometricFields = <String>[];
        _applyAiPlanToState(cachedPlan);
        _isLoadingPlan = false;
        notifyListeners();
      } else {
        _isLoadingPlan = _weeklyRoutines.isEmpty;
        notifyListeners();
      }

      // 2. Consultar PostgreSQL (`GET /api/v1/routines/current`) filtrado por current_user.id
      AiGeneratedRoutinePlanModel cloudPlan =
          await _repository.loadCurrentAiRoutine();

      if (cloudPlan.requiresBiometrics) {
        _requiresBiometrics = true;
        _missingBiometricFields = cloudPlan.missingFields;
        _weeklyRoutines = <RoutineTemplateModel>[];
        _selectedRoutine = null;
        _sets = <WorkoutSetModel>[];
        _geminiRationale = cloudPlan.weeklyFocus.isNotEmpty
            ? cloudPlan.weeklyFocus
            : 'Completa peso, estatura y sexo biológico para calcular tus cargas personalizadas.';
        await _repository.clearCachedAiRoutinePlan();
        return;
      }

      _requiresBiometrics = false;
      _missingBiometricFields = <String>[];

      final bool signatureMismatch = _biometricSignature != null &&
          cloudPlan.biometricSignature != null &&
          cloudPlan.biometricSignature != _biometricSignature;

      if (forceRefresh ||
          signatureMismatch ||
          !cloudPlan.hasRoutine ||
          cloudPlan.days.length < 5) {
        _isGeneratingAiRoutine = true;
        notifyListeners();
        try {
          cloudPlan = await _repository.generateAiRoutine();
        } finally {
          _isGeneratingAiRoutine = false;
        }
      }

      if (cloudPlan.requiresBiometrics) {
        _requiresBiometrics = true;
        _missingBiometricFields = cloudPlan.missingFields;
        _weeklyRoutines = <RoutineTemplateModel>[];
        _selectedRoutine = null;
        _sets = <WorkoutSetModel>[];
        await _repository.clearCachedAiRoutinePlan();
        return;
      }

      if (cloudPlan.hasRoutine && cloudPlan.days.isNotEmpty) {
        _applyAiPlanToState(
          cloudPlan,
          resetSelection: forceRefresh || signatureMismatch,
        );
        await _repository.saveCachedAiRoutinePlan(cloudPlan);
      }

      TodayWorkoutPlanModel? plan;
      try {
        plan = await _repository.loadTodayWorkoutPlan();
      } catch (_) {
        plan = null;
      }
      _todayPlan = plan;
      _isRolloverActive = plan?.isRollover ?? false;
      _rolloverBanner = plan?.coachRolloverBanner;

      if (plan?.activeWorkout != null) {
        _activeWorkoutId = plan!.activeWorkout!.id;
        _syncSetsWithSelectedRoutine(
          incomingSets: plan.activeWorkout!.sets,
        );
        _sessionLbmScore = plan.activeWorkout!.lbmAllometricScore;
        final String? notes = plan.activeWorkout!.aiPrescriptionNotes;
        if (notes != null && notes.isNotEmpty) {
          _geminiRationale = notes;
        }
      } else {
        _syncSetsWithSelectedRoutine();
      }
    } catch (e) {
      final String clean = ApiErrorSanitizer.sanitizeRawErrorString(e);
      if (clean != ApiErrorSanitizer.cloudReconnectingMessage) {
        _errorMessage = clean;
      }
    } finally {
      _isLoadingPlan = false;
      _isGeneratingAiRoutine = false;
      notifyListeners();
    }
  }

  /// Dispara `POST /api/v1/routines/generate-ai` para regenerar la rutina con la biometría real del usuario actual.
  Future<void> regenerateRoutineWithAi() async {
    _isGeneratingAiRoutine = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _resolveUserBiometricsBaseline();
      await _repository.clearCachedAiRoutinePlan();
      final AiGeneratedRoutinePlanModel aiPlan =
          await _repository.generateAiRoutine();

      if (aiPlan.requiresBiometrics) {
        _requiresBiometrics = true;
        _missingBiometricFields = aiPlan.missingFields;
        _weeklyRoutines = <RoutineTemplateModel>[];
        _selectedRoutine = null;
        _sets = <WorkoutSetModel>[];
        _geminiRationale = aiPlan.weeklyFocus.isNotEmpty
            ? aiPlan.weeklyFocus
            : 'Completa peso, estatura y sexo biológico antes de generar tu rutina IA.';
        return;
      }

      _requiresBiometrics = false;
      _missingBiometricFields = <String>[];

      if (aiPlan.days.isNotEmpty) {
        await _repository.saveCachedAiRoutinePlan(aiPlan);
        _selectedRoutine = aiPlan.days.first;
        _activeWorkoutId = 'local_session_day_${_selectedRoutine!.dayOfWeek}';
        _applyAiPlanToState(aiPlan, resetSelection: true);
      }
    } catch (e) {
      _errorMessage = ApiErrorSanitizer.sanitizeRawErrorString(e);
    } finally {
      _isGeneratingAiRoutine = false;
      notifyListeners();
    }
  }

  void selectRoutineTemplate(RoutineTemplateModel routine) {
    _selectedRoutine = routine;
    _sets = <WorkoutSetModel>[];
    _syncSetsWithSelectedRoutine(resetSelection: true);
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
      _syncSetsWithSelectedRoutine(
        incomingSets: session.sets,
        resetSelection: true,
      );
      _sessionLbmScore = session.lbmAllometricScore;
      final String? notes = session.aiPrescriptionNotes;
      if (notes != null && notes.isNotEmpty) {
        _geminiRationale = notes;
      } else {
        _geminiRationale =
            'Sesión "${routine.name}" iniciada con sobrecarga progresiva semanal calculada desde PostgreSQL.';
      }
    } catch (_) {
      _activeWorkoutId = 'local_session_day_${routine.dayOfWeek}';
      _syncSetsWithSelectedRoutine(resetSelection: true);
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
    notifyListeners();

    _restTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (_remainingRestSeconds <= 0) {
        timer.cancel();
      } else {
        _remainingRestSeconds--;
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
    _isSubmittingSet = true;
    _errorMessage = null;
    notifyListeners();

    final double localE1Rm = double.parse(
      (actualWeightKg * (1.0 + (actualReps / 30.0))).toStringAsFixed(1),
    );

    _sets = _sets.map((WorkoutSetModel s) {
      if (s.id == targetSet.id) {
        return s.copyWith(
          actualWeightKg: actualWeightKg,
          actualReps: actualReps,
          actualRpe: actualRpe,
          estimated1RmKg: localE1Rm,
          completed: true,
        );
      }
      return s;
    }).toList();

    final List<WorkoutSetModel> currentExSets =
        setsForExercise(_selectedExerciseIndex);
    WorkoutSetModel? nextPendingInSameEx;
    for (final WorkoutSetModel s in currentExSets) {
      if (!s.completed) {
        nextPendingInSameEx = s;
        break;
      }
    }
    _selectedSetId =
        (nextPendingInSameEx ??
                (currentExSets.isNotEmpty ? currentExSets.last : targetSet))
            .id;

    _projectedEloDelta += completedBinaryUi ? 4 : 1;
    _sessionLbmScore = double.parse(
      (_sessionLbmScore + (actualWeightKg * actualReps * 0.012))
          .toStringAsFixed(1),
    );
    _startRestCountdown(targetSet.restSeconds > 0 ? targetSet.restSeconds : 120);

    try {
      final String? wId = _activeWorkoutId;
      if (wId != null && !wId.startsWith('local_')) {
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
            : targetSet.restSeconds;
        _startRestCountdown(nextRest);
      }
    } catch (_) {
      // Mantiene el progreso local sin arrojar error bloqueante si el ejercicio es de la rutina IA de 6 ejercicios
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
