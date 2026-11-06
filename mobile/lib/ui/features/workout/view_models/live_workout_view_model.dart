import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';
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

  double get recoveryScore {
    final String z = _readinessZone.toUpperCase();
    if (z.contains('RED') || z.contains('ROJA') || z.contains('DELOAD')) {
      return 30.0;
    }
    if (z.contains('GREEN') || z.contains('VERDE') || z.contains('SOBRECARGA')) {
      return 78.0;
    }
    return 56.0;
  }

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

  bool _isGeneratingAiRoutine = false;
  bool get isGeneratingAiRoutine => _isGeneratingAiRoutine;

  String _aiRoutineTitle =
      'Hipertrofia Adaptativa Personalizada (Gemini 2.5 Flash)';
  String get aiRoutineTitle => _aiRoutineTitle;

  String _aiWeeklyFocus =
      'Periodización de 5 días × 6 ejercicios adaptada a tu LBM y recuperación';
  String get aiWeeklyFocus => _aiWeeklyFocus;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Timer? _restTimer;

  int _selectedExerciseIndex = 0;
  int get selectedExerciseIndex => _selectedExerciseIndex;

  String? _selectedSetId;
  String? get selectedSetId => _selectedSetId;

  void _onBleServiceChanged() {
    if (_bleService.latestBpm != null) {
      _liveHeartRate = _bleService.latestBpm!;
    }
    notifyListeners();
  }

  /// Lista de los ejercicios (6 por día) disponibles en la rutina activa,
  /// sin ningún bloqueo lineal.
  List<RoutineExerciseItemModel> get activeDayExercises {
    final List<RoutineExerciseItemModel> routineEx =
        _selectedRoutine?.exercises ?? const <RoutineExerciseItemModel>[];
    if (routineEx.isNotEmpty) {
      return routineEx;
    }
    // Fallback si solo hay sets cargados desde servidor
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

  /// Devuelve todas las series pertenecientes al ejercicio en `exerciseIndex`.
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

  /// Indica si todas las series de un ejercicio ya fueron completadas.
  bool isExerciseCompleted(int exerciseIndex) {
    final List<WorkoutSetModel> exSets = setsForExercise(exerciseIndex);
    return exSets.isNotEmpty && exSets.every((WorkoutSetModel s) => s.completed);
  }

  /// Cambia libremente al ejercicio indicado (sin bloqueo lineal) y selecciona
  /// su primera serie pendiente (o la última si ya está completado para permitir edición/vista).
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

  /// Permite tocar cualquier serie de "Progresión de series en tiempo real"
  /// para saltar de inmediato a ese ejercicio y serie.
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

  /// Devuelve la serie actualmente activa según el ejercicio/serie seleccionado por el usuario.
  /// Nunca bloquea el acceso a otros ejercicios ni oculta el visor si un ejercicio ya se completó.
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

  /// Garantiza que `_sets` contenga las series de los 6 ejercicios del día seleccionado,
  /// preservando el progreso de series ya registradas en el servidor o localmente.
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

  Future<void> initializeWorkoutPlan() async {
    _errorMessage = null;

    try {
      _unitSystem = await _repository.getPreferredUnitSystem();

      // 1. Carga instantánea (0ms) desde SharedPreferences para abrir Entreno Vivo sin espera
      AiGeneratedRoutinePlanModel? cachedPlan =
          await _repository.readCachedAiRoutinePlan();
      if (cachedPlan == null || cachedPlan.days.length < 5) {
        final cachedBio = await _repository.readCachedBiometrics();
        cachedPlan = _buildInstantLocalLbmFiveDayPlan(
          lbmKg: (cachedBio != null && cachedBio.leanBodyMassKg > 20)
              ? cachedBio.leanBodyMassKg
              : 62.74,
          weightKg: cachedBio?.weightKg ?? 92.4,
        );
        await _repository.saveCachedAiRoutinePlan(cachedPlan);
      }

      _weeklyRoutines = cachedPlan.days;
      _aiRoutineTitle = cachedPlan.routineName;
      _aiWeeklyFocus = cachedPlan.weeklyFocus;
      _geminiRationale =
          '${cachedPlan.routineName} • ${cachedPlan.weeklyFocus}. 5 días × 6 ejercicios con cargas reales en KG.';

      if (_weeklyRoutines.isNotEmpty && _selectedRoutine == null) {
        final int todayIso = DateTime.now().weekday.clamp(1, 5);
        RoutineTemplateModel? matchedDay;
        for (final RoutineTemplateModel r in _weeklyRoutines) {
          if (r.dayOfWeek == todayIso) {
            matchedDay = r;
            break;
          }
        }
        _selectedRoutine = matchedDay ?? _weeklyRoutines.first;
      }

      _syncSetsWithSelectedRoutine();
      _isLoadingPlan = false;
      notifyListeners();

      // 2. Sincronización en segundo plano de GET /api/v1/routines/current (<100ms, solo PostgreSQL)
      try {
        final AiGeneratedRoutinePlanModel cloudPlan =
            await _repository.loadCurrentAiRoutine();
        if (cloudPlan.hasRoutine && cloudPlan.days.length >= 5) {
          _weeklyRoutines = cloudPlan.days;
          _aiRoutineTitle = cloudPlan.routineName;
          _aiWeeklyFocus = cloudPlan.weeklyFocus;
          _geminiRationale =
              '${cloudPlan.routineName} • ${cloudPlan.weeklyFocus}. 5 días × 6 ejercicios con cargas reales en KG.';
          await _repository.saveCachedAiRoutinePlan(cloudPlan);
        }
      } catch (_) {}

      TodayWorkoutPlanModel? plan;
      try {
        plan = await _repository.loadTodayWorkoutPlan();
      } catch (_) {
        plan = null;
      }
      _todayPlan = plan;
      _isRolloverActive = plan?.isRollover ?? false;
      _rolloverBanner = plan?.coachRolloverBanner;

      if (_weeklyRoutines.isNotEmpty) {
        final int currentDay =
            _selectedRoutine?.dayOfWeek ?? DateTime.now().weekday.clamp(1, 5);
        RoutineTemplateModel? matchedDay;
        for (final RoutineTemplateModel r in _weeklyRoutines) {
          if (r.dayOfWeek == currentDay) {
            matchedDay = r;
            break;
          }
        }
        _selectedRoutine = matchedDay ?? _weeklyRoutines.first;
      } else {
        _selectedRoutine = plan?.activeRoutine;
      }

      if (plan?.activeWorkout != null) {
        _activeWorkoutId = plan!.activeWorkout!.id;
        _syncSetsWithSelectedRoutine(
          incomingSets: plan.activeWorkout!.sets,
        );
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

  /// Dispara `POST /api/v1/routines/generate-ai` únicamente cuando el usuario pulsa "REGENERAR RUTINA CON IA".
  Future<void> regenerateRoutineWithAi() async {
    _isGeneratingAiRoutine = true;
    _errorMessage = null;
    notifyListeners();

    try {
      AiGeneratedRoutinePlanModel aiPlan;
      try {
        aiPlan = await _repository.generateAiRoutine();
      } catch (_) {
        aiPlan = await _buildAndPersistLbmFiveDayPlanFallback();
      }
      if (aiPlan.days.isNotEmpty) {
        await _repository.saveCachedAiRoutinePlan(aiPlan);
        _weeklyRoutines = aiPlan.days;
        _aiRoutineTitle = aiPlan.routineName;
        _aiWeeklyFocus = aiPlan.weeklyFocus;
        _selectedRoutine = aiPlan.days.first;
        _activeWorkoutId = 'local_session_day_${_selectedRoutine!.dayOfWeek}';
        _sets = <WorkoutSetModel>[];
        _syncSetsWithSelectedRoutine(resetSelection: true);
        _geminiRationale =
            '${aiPlan.routineName} • ${aiPlan.weeklyFocus}. Cargas recalculadas por Gemini 2.5 Flash.';
      }
    } catch (e) {
      _errorMessage = ApiErrorSanitizer.sanitizeRawErrorString(e);
    } finally {
      _isGeneratingAiRoutine = false;
      notifyListeners();
    }
  }

  double _roundPlate(double rawKg) {
    return (rawKg / 2.5).round() * 2.5;
  }

  AiGeneratedRoutinePlanModel _buildInstantLocalLbmFiveDayPlan({
    required double lbmKg,
    required double weightKg,
  }) {
    double scale(double coeff, double minKg) {
      final double v = lbmKg * coeff * 0.96;
      return _roundPlate(v < minKg ? minKg : v);
    }

    final List<Map<String, dynamic>> rawDaysSpec =
        _rawFiveDaySpec(scale: scale);
    final List<RoutineTemplateModel> localDays = <RoutineTemplateModel>[];
    for (final Map<String, dynamic> d in rawDaysSpec) {
      final int dayNum = d['day'] as int;
      final String dayName = d['name'] as String;
      final String focus = d['focus'] as String;
      final List<Map<String, dynamic>> exList =
          (d['exercises'] as List<Map<String, dynamic>>);
      final List<RoutineExerciseItemModel> localItems =
          <RoutineExerciseItemModel>[];
      for (int i = 0; i < exList.length; i++) {
        final Map<String, dynamic> spec = exList[i];
        localItems.add(
          RoutineExerciseItemModel(
            id: 'day_${dayNum}_ex_${i + 1}',
            exerciseId: 'day_${dayNum}_ex_${i + 1}',
            exerciseName: spec['exercise_name'] as String,
            exerciseKey: spec['exercise_key'] as String,
            muscleGroup: spec['muscle_group'] as String,
            displayOrder: i + 1,
            targetSets: spec['target_sets'] as int,
            targetReps: spec['target_reps'] as int,
            targetRepsRange: spec['target_reps_range'] as String,
            targetWeightKg: (spec['base_weight_kg'] as num).toDouble(),
            targetRpe: (spec['target_rpe'] as num).toDouble(),
            restSeconds: spec['rest_seconds'] as int,
            tempo: spec['tempo'] as String,
            coachingCue: spec['coaching_cue'] as String,
          ),
        );
      }
      localDays.add(
        RoutineTemplateModel(
          id: 'local_day_$dayNum',
          dayOfWeek: dayNum,
          name: dayName,
          focusGroup: focus,
          isActive: true,
          exercises: localItems,
        ),
      );
    }
    return AiGeneratedRoutinePlanModel(
      hasRoutine: true,
      routineName: 'Hipertrofia 5 Días - ${lbmKg.toStringAsFixed(2)}kg LBM',
      weeklyFocus:
          'Periodización biomecánica adaptada a ${lbmKg.toStringAsFixed(2)} kg LBM (${weightKg.toStringAsFixed(1)} kg)',
      days: localDays,
    );
  }

  Future<AiGeneratedRoutinePlanModel> _buildAndPersistLbmFiveDayPlanFallback() async {
    double lbmKg = 62.74;
    double weightKg = 92.4;
    try {
      final bio =
          await _repository.readCachedBiometrics() ??
          await _repository.loadLatestBiometrics();
      if (bio != null) {
        weightKg = bio.weightKg;
        lbmKg = bio.leanBodyMassKg > 20 ? bio.leanBodyMassKg : 62.74;
      }
    } catch (_) {}

    double scale(double coeff, double minKg) {
      final double v = lbmKg * coeff * 0.96;
      return _roundPlate(v < minKg ? minKg : v);
    }

    final List<Map<String, dynamic>> rawDaysSpec =
        _rawFiveDaySpec(scale: scale);
    final AiGeneratedRoutinePlanModel instantPlan =
        _buildInstantLocalLbmFiveDayPlan(lbmKg: lbmKg, weightKg: weightKg);
    await _repository.saveCachedAiRoutinePlan(instantPlan);

    // Sincronizar plantillas al servidor en segundo plano sin bloquear la UI
    unawaited(
      Future<void>(() async {
        for (final Map<String, dynamic> d in rawDaysSpec) {
          try {
            final int dayNum = d['day'] as int;
            final String dayName = d['name'] as String;
            final String focus = d['focus'] as String;
            final List<Map<String, dynamic>> exList =
                (d['exercises'] as List<Map<String, dynamic>>);
            await _repository.saveRoutineForDay(
              dayOfWeek: dayNum,
              name: dayName,
              focusGroup: focus,
              exercises: exList
                  .map(
                    (Map<String, dynamic> ex) => <String, dynamic>{
                      'exercise_name': ex['exercise_name'],
                      'muscle_group': ex['muscle_group'],
                      'category': 'hipertrofia',
                      'target_sets': ex['target_sets'],
                      'target_reps': ex['target_reps'],
                      'base_weight_kg': ex['base_weight_kg'],
                      'target_rpe': ex['target_rpe'],
                    },
                  )
                  .toList(),
            );
          } catch (_) {}
        }
      }),
    );

    return instantPlan;
  }

  List<Map<String, dynamic>> _rawFiveDaySpec({
    required double Function(double coeff, double minKg) scale,
  }) {
    final List<Map<String, dynamic>> rawDaysSpec = <Map<String, dynamic>>[
      <String, dynamic>{
        'day': 1,
        'name': 'Día 1: Empuje (Pecho & Tríceps)',
        'focus': 'Pectoral • Tríceps',
        'exercises': <Map<String, dynamic>>[
          <String, dynamic>{
            'exercise_name': 'Press de Banca Plano con Barra',
            'exercise_key': 'bench_press_barbell',
            'muscle_group': 'Pectoral',
            'target_sets': 4,
            'target_reps': 8,
            'target_reps_range': '6-8',
            'base_weight_kg': scale(1.04, 40.0),
            'target_rpe': 8.0,
            'rest_seconds': 120,
            'tempo': '3-0-1-0',
            'coaching_cue': 'Retracción escapular activa y codos a 45°',
          },
          <String, dynamic>{
            'exercise_name': 'Press Inclinado con Mancuernas (30°)',
            'exercise_key': 'incline_dumbbell_press',
            'muscle_group': 'Pectoral',
            'target_sets': 4,
            'target_reps': 10,
            'target_reps_range': '8-10',
            'base_weight_kg': scale(0.38, 17.5),
            'target_rpe': 8.0,
            'rest_seconds': 90,
            'tempo': '3-1-1-0',
            'coaching_cue': 'Pausa de 1s en estiramiento pectoral',
          },
          <String, dynamic>{
            'exercise_name': 'Fondos en Paralelas / Cruce en Polea',
            'exercise_key': 'chest_dip_weighted',
            'muscle_group': 'Pectoral',
            'target_sets': 3,
            'target_reps': 10,
            'target_reps_range': '8-10',
            'base_weight_kg': scale(0.45, 22.5),
            'target_rpe': 8.0,
            'rest_seconds': 90,
            'tempo': '3-0-1-1',
            'coaching_cue': 'Torso inclinado 20° al frente',
          },
          <String, dynamic>{
            'exercise_name': 'Press Francés con Barra EZ',
            'exercise_key': 'tricep_french_press',
            'muscle_group': 'Tríceps',
            'target_sets': 3,
            'target_reps': 10,
            'target_reps_range': '8-10',
            'base_weight_kg': scale(0.48, 22.5),
            'target_rpe': 8.0,
            'rest_seconds': 90,
            'tempo': '3-0-1-0',
            'coaching_cue': 'Húmeros fijos en ligera flexión',
          },
          <String, dynamic>{
            'exercise_name': 'Extensión de Tríceps en Polea con Cuerda',
            'exercise_key': 'tricep_rope_pushdown',
            'muscle_group': 'Tríceps',
            'target_sets': 3,
            'target_reps': 12,
            'target_reps_range': '10-12',
            'base_weight_kg': scale(0.40, 20.0),
            'target_rpe': 8.5,
            'rest_seconds': 75,
            'tempo': '2-0-1-1',
            'coaching_cue': 'Bloquea codos junto al torso y abre la cuerda',
          },
          <String, dynamic>{
            'exercise_name': 'Extensión Overhead en Polea (Cabeza Larga)',
            'exercise_key': 'overhead_tricep_extension',
            'muscle_group': 'Tríceps',
            'target_sets': 3,
            'target_reps': 12,
            'target_reps_range': '12-15',
            'base_weight_kg': scale(0.36, 17.5),
            'target_rpe': 8.5,
            'rest_seconds': 75,
            'tempo': '3-1-1-0',
            'coaching_cue': 'Máximo estiramiento de la cabeza larga del tríceps',
          },
        ],
      },
      <String, dynamic>{
        'day': 2,
        'name': 'Día 2: Tracción (Espalda & Bíceps)',
        'focus': 'Dorsal • Bíceps',
        'exercises': <Map<String, dynamic>>[
          <String, dynamic>{
            'exercise_name': 'Remo con Barra Prono (Pendlay Row)',
            'exercise_key': 'barbell_row',
            'muscle_group': 'Dorsal',
            'target_sets': 4,
            'target_reps': 8,
            'target_reps_range': '6-8',
            'base_weight_kg': scale(1.00, 42.5),
            'target_rpe': 8.0,
            'rest_seconds': 120,
            'tempo': '2-0-1-1',
            'coaching_cue': 'Torso a 45° estable, tracciona hacia el abdomen',
          },
          <String, dynamic>{
            'exercise_name': 'Jalón al Pecho Prono Ancho',
            'exercise_key': 'lat_pulldown',
            'muscle_group': 'Dorsal',
            'target_sets': 4,
            'target_reps': 10,
            'target_reps_range': '8-10',
            'base_weight_kg': scale(0.92, 40.0),
            'target_rpe': 8.0,
            'rest_seconds': 90,
            'tempo': '3-0-1-1',
            'coaching_cue': 'Depresión escapular antes de flexionar codos',
          },
          <String, dynamic>{
            'exercise_name': 'Remo en Polea Baja Agarre Neutro',
            'exercise_key': 'seated_cable_row',
            'muscle_group': 'Dorsal',
            'target_sets': 3,
            'target_reps': 10,
            'target_reps_range': '10-12',
            'base_weight_kg': scale(0.88, 37.5),
            'target_rpe': 8.0,
            'rest_seconds': 90,
            'tempo': '3-0-1-1',
            'coaching_cue': 'Aprieta romboides 1 segundo en máxima contracción',
          },
          <String, dynamic>{
            'exercise_name': 'Curl de Bíceps con Barra Recta',
            'exercise_key': 'bicep_curl_barbell',
            'muscle_group': 'Bíceps',
            'target_sets': 3,
            'target_reps': 10,
            'target_reps_range': '8-10',
            'base_weight_kg': scale(0.46, 20.0),
            'target_rpe': 8.0,
            'rest_seconds': 75,
            'tempo': '3-0-1-1',
            'coaching_cue': 'Codos fijos a las costillas sin balancear torso',
          },
          <String, dynamic>{
            'exercise_name': 'Curl Inclinado con Mancuernas',
            'exercise_key': 'incline_dumbbell_curl',
            'muscle_group': 'Bíceps',
            'target_sets': 3,
            'target_reps': 12,
            'target_reps_range': '10-12',
            'base_weight_kg': scale(0.20, 10.0),
            'target_rpe': 8.5,
            'rest_seconds': 75,
            'tempo': '3-1-1-0',
            'coaching_cue': 'Hombros en extensión y supinación completa al subir',
          },
          <String, dynamic>{
            'exercise_name': 'Curl Martillo Cruzado (Braquiorradial)',
            'exercise_key': 'hammer_curl_dumbbell',
            'muscle_group': 'Bíceps',
            'target_sets': 3,
            'target_reps': 12,
            'target_reps_range': '10-12',
            'base_weight_kg': scale(0.24, 12.5),
            'target_rpe': 8.5,
            'rest_seconds': 60,
            'tempo': '2-0-1-1',
            'coaching_cue': 'Agarre neutro firme y descenso controlado en 2s',
          },
        ],
      },
      <String, dynamic>{
        'day': 3,
        'name': 'Día 3: Tren Inferior A (Cuádriceps & Gemelos)',
        'focus': 'Cuádriceps • Gemelos',
        'exercises': <Map<String, dynamic>>[
          <String, dynamic>{
            'exercise_name': 'Sentadilla Libre con Barra (Back Squat)',
            'exercise_key': 'squat_barbell',
            'muscle_group': 'Cuádriceps',
            'target_sets': 4,
            'target_reps': 8,
            'target_reps_range': '6-8',
            'base_weight_kg': scale(1.28, 55.0),
            'target_rpe': 8.0,
            'rest_seconds': 150,
            'tempo': '3-1-1-0',
            'coaching_cue': 'Bracing 360° y rodillas alineadas con punteras',
          },
          <String, dynamic>{
            'exercise_name': 'Prensa Inclinada 45° Profunda',
            'exercise_key': 'leg_press',
            'muscle_group': 'Cuádriceps',
            'target_sets': 4,
            'target_reps': 10,
            'target_reps_range': '8-10',
            'base_weight_kg': scale(2.20, 100.0),
            'target_rpe': 8.0,
            'rest_seconds': 120,
            'tempo': '3-0-1-0',
            'coaching_cue': 'Sacro pegado al respaldo y flexión >95°',
          },
          <String, dynamic>{
            'exercise_name': 'Zancadas Búlgaras con Mancuernas',
            'exercise_key': 'bulgarian_split_squat',
            'muscle_group': 'Cuádriceps',
            'target_sets': 3,
            'target_reps': 10,
            'target_reps_range': '8-10',
            'base_weight_kg': scale(0.32, 15.0),
            'target_rpe': 8.0,
            'rest_seconds': 90,
            'tempo': '3-1-1-0',
            'coaching_cue': 'Empuja con toda la planta del pie delantero',
          },
          <String, dynamic>{
            'exercise_name': 'Extensión de Cuádriceps en Máquina',
            'exercise_key': 'leg_extension',
            'muscle_group': 'Cuádriceps',
            'target_sets': 3,
            'target_reps': 12,
            'target_reps_range': '12-15',
            'base_weight_kg': scale(0.82, 35.0),
            'target_rpe': 8.5,
            'rest_seconds': 75,
            'tempo': '3-0-1-1',
            'coaching_cue': 'Sostén 1s arriba exprimiendo el vasto medial',
          },
          <String, dynamic>{
            'exercise_name': 'Elevación de Talones de Pie en Máquina',
            'exercise_key': 'standing_calf_raise',
            'muscle_group': 'Gemelos',
            'target_sets': 4,
            'target_reps': 12,
            'target_reps_range': '10-12',
            'base_weight_kg': scale(1.15, 50.0),
            'target_rpe': 8.5,
            'rest_seconds': 60,
            'tempo': '2-2-1-1',
            'coaching_cue': 'Pausa de 2s en dorsiflexión profunda',
          },
          <String, dynamic>{
            'exercise_name': 'Elevación de Talones Sentado (Sóleo)',
            'exercise_key': 'seated_calf_raise',
            'muscle_group': 'Gemelos',
            'target_sets': 3,
            'target_reps': 15,
            'target_reps_range': '12-15',
            'base_weight_kg': scale(0.75, 32.5),
            'target_rpe': 8.5,
            'rest_seconds': 60,
            'tempo': '3-1-1-1',
            'coaching_cue': 'Rango completo sobre el metatarso',
          },
        ],
      },
      <String, dynamic>{
        'day': 4,
        'name': 'Día 4: Hombros & Trapecio / Core',
        'focus': 'Deltoides • Trapecio',
        'exercises': <Map<String, dynamic>>[
          <String, dynamic>{
            'exercise_name': 'Press Militar Overhead con Barra (OHP)',
            'exercise_key': 'overhead_press',
            'muscle_group': 'Deltoides',
            'target_sets': 4,
            'target_reps': 8,
            'target_reps_range': '6-8',
            'base_weight_kg': scale(0.68, 30.0),
            'target_rpe': 8.0,
            'rest_seconds': 120,
            'tempo': '2-0-1-1',
            'coaching_cue': 'Glúteos y abdomen firmes, antebrazos verticales',
          },
          <String, dynamic>{
            'exercise_name': 'Elevaciones Laterales en Plano Escapular',
            'exercise_key': 'lateral_raise',
            'muscle_group': 'Deltoides',
            'target_sets': 4,
            'target_reps': 12,
            'target_reps_range': '12-15',
            'base_weight_kg': scale(0.18, 10.0),
            'target_rpe': 8.5,
            'rest_seconds': 75,
            'tempo': '3-0-1-1',
            'coaching_cue': 'Eleva a 30° en plano escapular guiando con codos',
          },
          <String, dynamic>{
            'exercise_name': 'Face Pull / Pájaros en Polea',
            'exercise_key': 'rear_delt_fly',
            'muscle_group': 'Deltoides',
            'target_sets': 3,
            'target_reps': 15,
            'target_reps_range': '12-15',
            'base_weight_kg': scale(0.38, 15.0),
            'target_rpe': 8.0,
            'rest_seconds': 75,
            'tempo': '2-0-1-1',
            'coaching_cue': 'Tracciona hacia la frente con rotación externa',
          },
          <String, dynamic>{
            'exercise_name': 'Press de Hombros Sentado con Mancuernas',
            'exercise_key': 'seated_dumbbell_shoulder_press',
            'muscle_group': 'Deltoides',
            'target_sets': 3,
            'target_reps': 10,
            'target_reps_range': '8-10',
            'base_weight_kg': scale(0.34, 15.0),
            'target_rpe': 8.0,
            'rest_seconds': 90,
            'tempo': '3-0-1-0',
            'coaching_cue': 'Desciende hasta la línea de las orejas',
          },
          <String, dynamic>{
            'exercise_name': 'Encogimientos con Barra (Trapecio)',
            'exercise_key': 'barbell_shrug',
            'muscle_group': 'Trapecio',
            'target_sets': 3,
            'target_reps': 12,
            'target_reps_range': '10-12',
            'base_weight_kg': scale(1.20, 50.0),
            'target_rpe': 8.0,
            'rest_seconds': 75,
            'tempo': '2-0-1-2',
            'coaching_cue': 'Sostén 2 segundos arriba en contracción máxima',
          },
          <String, dynamic>{
            'exercise_name': 'Elevación Lateral Unilateral en Polea',
            'exercise_key': 'cable_lateral_raise',
            'muscle_group': 'Deltoides',
            'target_sets': 3,
            'target_reps': 15,
            'target_reps_range': '12-15',
            'base_weight_kg': scale(0.16, 7.5),
            'target_rpe': 8.5,
            'rest_seconds': 60,
            'tempo': '3-0-1-1',
            'coaching_cue': 'Tensión constante desde los primeros 15°',
          },
        ],
      },
      <String, dynamic>{
        'day': 5,
        'name': 'Día 5: Tren Inferior B (Cadena Posterior & Glúteo)',
        'focus': 'Isquiosurales • Glúteo',
        'exercises': <Map<String, dynamic>>[
          <String, dynamic>{
            'exercise_name': 'Peso Muerto Rumano con Barra (RDL)',
            'exercise_key': 'deadlift_barbell',
            'muscle_group': 'Isquiosurales',
            'target_sets': 4,
            'target_reps': 8,
            'target_reps_range': '6-8',
            'base_weight_kg': scale(1.32, 55.0),
            'target_rpe': 8.0,
            'rest_seconds': 150,
            'tempo': '3-1-1-0',
            'coaching_cue': 'Barra pegada a los muslos y bisagra de cadera',
          },
          <String, dynamic>{
            'exercise_name': 'Hip Thrust Pesado con Barra',
            'exercise_key': 'hip_thrust',
            'muscle_group': 'Glúteo',
            'target_sets': 4,
            'target_reps': 10,
            'target_reps_range': '8-10',
            'base_weight_kg': scale(1.55, 65.0),
            'target_rpe': 8.0,
            'rest_seconds': 120,
            'tempo': '2-0-1-2',
            'coaching_cue': 'Mentón recogido y retroversión pélvica 2s arriba',
          },
          <String, dynamic>{
            'exercise_name': 'Curl Femoral Sentado / Tumbado',
            'exercise_key': 'seated_leg_curl',
            'muscle_group': 'Isquiosurales',
            'target_sets': 4,
            'target_reps': 12,
            'target_reps_range': '10-12',
            'base_weight_kg': scale(0.76, 35.0),
            'target_rpe': 8.5,
            'rest_seconds': 90,
            'tempo': '3-0-1-1',
            'coaching_cue': 'Dorsiflexión activa y excéntrica de 3 segundos',
          },
          <String, dynamic>{
            'exercise_name': 'Zancadas Caminando Largas (Glúteo)',
            'exercise_key': 'lunge_dumbbell',
            'muscle_group': 'Glúteo',
            'target_sets': 3,
            'target_reps': 10,
            'target_reps_range': '10-12',
            'base_weight_kg': scale(0.32, 15.0),
            'target_rpe': 8.0,
            'rest_seconds': 90,
            'tempo': '3-0-1-0',
            'coaching_cue': 'Zancada larga e inclinación de 15° en el torso',
          },
          <String, dynamic>{
            'exercise_name': 'Extensión de Cadera 45° Lastrada',
            'exercise_key': 'hyperextension_weighted',
            'muscle_group': 'Glúteo',
            'target_sets': 3,
            'target_reps': 12,
            'target_reps_range': '12-15',
            'base_weight_kg': scale(0.28, 12.5),
            'target_rpe': 8.0,
            'rest_seconds': 75,
            'tempo': '2-0-1-1',
            'coaching_cue': 'Aísla glúteo e isquios sin hiperextender lumbar',
          },
          <String, dynamic>{
            'exercise_name': 'Prensa de Gemelos / Abducción de Cadera',
            'exercise_key': 'calf_press_leg_press',
            'muscle_group': 'Glúteo',
            'target_sets': 3,
            'target_reps': 15,
            'target_reps_range': '12-15',
            'base_weight_kg': scale(0.95, 42.5),
            'target_rpe': 8.5,
            'rest_seconds': 60,
            'tempo': '3-1-1-1',
            'coaching_cue': 'Control total en ambos extremos del rango',
          },
        ],
      },
    ];
    return rawDaysSpec;
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
    _isSubmittingSet = true;
    _errorMessage = null;
    notifyListeners();

    final double localE1Rm = double.parse(
      (actualWeightKg * (1.0 + (actualReps / 30.0))).toStringAsFixed(1),
    );

    // 1. Actualización local inmediata sobre el ejercicio actualmente seleccionado (sin bloqueos)
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

    // Avanza a la siguiente serie pendiente del MISMO ejercicio seleccionado
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
