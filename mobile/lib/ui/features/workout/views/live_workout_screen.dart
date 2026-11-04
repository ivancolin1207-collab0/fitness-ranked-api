import 'package:flutter/material.dart';
import '../../../../data/models/workout_models.dart';
import '../../../core/app_theme.dart';
import '../view_models/live_workout_view_model.dart';
import 'set_binary_feedback_sheet.dart';

class LiveWorkoutScreen extends StatelessWidget {
  final LiveWorkoutViewModel viewModel;

  const LiveWorkoutScreen({
    super.key,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (BuildContext context, _) {
        final WorkoutSetModel? activeSet = viewModel.currentActiveSet;
        final bool hasStartedSession = viewModel.activeWorkoutId != null;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'ENTRENO ADAPTATIVO & RUTINAS',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'Configurar Rutina Semanal',
                icon: const Icon(
                  Icons.calendar_month_outlined,
                  color: ApexTheme.cyanElectric,
                ),
                onPressed: () => _openRoutineBuilderModal(context),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ActionChip(
                  backgroundColor: ApexTheme.cardGraphite,
                  side: const BorderSide(color: ApexTheme.voltAccent),
                  label: Text(
                    viewModel.unitSystem,
                    style: const TextStyle(
                      color: ApexTheme.voltAccent,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  onPressed: viewModel.toggleUnitSystem,
                ),
              ),
            ],
          ),
          body: viewModel.isLoadingPlan
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: viewModel.initializeWorkoutPlan,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: <Widget>[
                          if (viewModel.errorMessage != null)
                            _buildErrorBanner(viewModel.errorMessage!),
                          if (viewModel.isRolloverActive &&
                              viewModel.rolloverBanner != null)
                            _buildRolloverAlertBanner(
                              viewModel.rolloverBanner!,
                            ),
                          _buildLiveTelemetryHeader(),
                          const SizedBox(height: 12),
                          _buildWeeklyRoutinesSelector(context),
                          const SizedBox(height: 12),
                          _buildGeminiAdaptiveBanner(),
                          const SizedBox(height: 14),
                          if (!hasStartedSession)
                            _buildStartRoutineCard(context)
                          else if (activeSet != null)
                            _buildActiveSetCard(context, activeSet)
                          else
                            _buildSessionCompletedCard(),
                          if (hasStartedSession && viewModel.sets.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 16),
                            _buildSetProgressionList(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildErrorBanner(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ApexTheme.deloadCrimson.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ApexTheme.deloadCrimson),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: ApexTheme.deloadCrimson,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildRolloverAlertBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ApexTheme.warningAmber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ApexTheme.warningAmber, width: 1.4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.event_repeat_rounded,
            color: ApexTheme.warningAmber,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'ARRASTRE INTELIGENTE DE RUTINA (ROLLOVER ACTIVO)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: ApexTheme.warningAmber,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: ApexTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyRoutinesSelector(BuildContext context) {
    final List<RoutineTemplateModel> routines = viewModel.weeklyRoutines;
    final RoutineTemplateModel? selected = viewModel.selectedRoutine;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'PLANIFICACIÓN SEMANAL POR DÍA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: ApexTheme.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _openRoutineBuilderModal(context),
                  icon: const Icon(
                    Icons.add_circle_outline,
                    size: 16,
                    color: ApexTheme.voltAccent,
                  ),
                  label: const Text(
                    'Editar / Crear Día',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: ApexTheme.voltAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (routines.isEmpty)
              const Text(
                'Aún no tienes rutinas configuradas. Pulsa "Editar / Crear Día" para armar tu semana.',
                style: TextStyle(fontSize: 12, color: ApexTheme.textMuted),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: routines.map((RoutineTemplateModel r) {
                    final bool isSelected = selected?.id == r.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: isSelected,
                        selectedColor: ApexTheme.voltAccent,
                        label: Text('${r.dayLabel}: ${r.name}'),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.black
                              : ApexTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                        onSelected: (_) => viewModel.selectRoutineTemplate(r),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartRoutineCard(BuildContext context) {
    final RoutineTemplateModel? routine = viewModel.selectedRoutine;
    if (routine == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: <Widget>[
              const Icon(
                Icons.fitness_center_rounded,
                color: ApexTheme.voltAccent,
                size: 40,
              ),
              const SizedBox(height: 10),
              const Text(
                'CONFIGURA TU PRIMERA RUTINA SEMANAL',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: ApexTheme.voltAccent,
                  foregroundColor: Colors.black,
                ),
                onPressed: () => _openRoutineBuilderModal(context),
                icon: const Icon(Icons.add),
                label: const Text('CREAR RUTINA POR DÍA'),
              ),
            ],
          ),
        ),
      );
    }

    final String unit = viewModel.unitSystem;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: ApexTheme.voltAccent, width: 1.4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${routine.dayLabel.toUpperCase()} • ${routine.name.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Enfoque: ${routine.focusGroup} • ${routine.exercises.length} ejercicios con sobrecarga progresiva',
                        style: const TextStyle(
                          fontSize: 12,
                          color: ApexTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...routine.exercises.map((RoutineExerciseItemModel ex) {
              final double w = viewModel.displayWeight(ex.targetWeightKg);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: ApexTheme.cyanElectric,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ex.exerciseName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      '${ex.targetSets}×${ex.targetReps} @ $w $unit (RPE ${ex.targetRpe.toStringAsFixed(1)})',
                      style: const TextStyle(
                        color: ApexTheme.voltAccent,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: ApexTheme.voltAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: viewModel.isStartingWorkout
                  ? null
                  : viewModel.startSelectedRoutine,
              icon: viewModel.isStartingWorkout
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: const Text(
                'INICIAR SESIÓN EN VIVO (SOBRECARGA PROGRESIVA)',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveTelemetryHeader() {
    final bool isResting = viewModel.remainingRestSeconds > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.timer_outlined,
                    color: isResting
                        ? ApexTheme.cyanElectric
                        : ApexTheme.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'DESCANSO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: ApexTheme.textMuted,
                          ),
                        ),
                        Text(
                          viewModel.formattedRestTimer,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: isResting
                                ? ApexTheme.cyanElectric
                                : ApexTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.favorite_rounded,
                  color: ApexTheme.deloadCrimson,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  '${viewModel.liveHeartRate} BPM',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ApexTheme.voltAccent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ApexTheme.voltAccent),
              ),
              child: Text(
                '${viewModel.projectedEloDelta >= 0 ? "+" : ""}${viewModel.projectedEloDelta} ELO',
                style: const TextStyle(
                  color: ApexTheme.voltAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeminiAdaptiveBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ApexTheme.cyanElectric.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ApexTheme.cyanElectric.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.auto_awesome_rounded,
            color: ApexTheme.cyanElectric,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'GEMINI COACH • ${viewModel.readinessZone}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: ApexTheme.cyanElectric,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  viewModel.geminiRationale,
                  style: const TextStyle(
                    fontSize: 13,
                    color: ApexTheme.textPrimary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSetCard(BuildContext context, WorkoutSetModel activeSet) {
    final String unit = viewModel.unitSystem;
    final double shownWeight =
        viewModel.displayWeight(activeSet.prescribedWeightKg);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: ApexTheme.voltAccent, width: 1.6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    activeSet.exerciseName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: ApexTheme.voltAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'SERIE ACTIVA #${activeSet.setNumber}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _PrescriptionPillar(
                  label: 'CARGA PRESCRITA',
                  value: '$shownWeight $unit',
                  accent: ApexTheme.voltAccent,
                ),
                _PrescriptionPillar(
                  label: 'REPETICIONES',
                  value: '${activeSet.prescribedReps} REPS',
                  accent: ApexTheme.textPrimary,
                ),
                _PrescriptionPillar(
                  label: 'INTENSIDAD',
                  value: 'RPE ${activeSet.prescribedRpe.toStringAsFixed(1)}',
                  accent: ApexTheme.cyanElectric,
                ),
              ],
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: ApexTheme.voltAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: viewModel.isSubmittingSet
                  ? null
                  : () => _openBinaryFeedbackModal(context, activeSet),
              icon: viewModel.isSubmittingSet
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.bolt_rounded),
              label: const Text(
                'FINALIZAR SERIE',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCompletedCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: <Widget>[
            const Icon(
              Icons.emoji_events_rounded,
              color: ApexTheme.voltAccent,
              size: 46,
            ),
            const SizedBox(height: 10),
            const Text(
              '¡RUTINA DEL DÍA COMPLETADA Y GUARDADA EN RENDER!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Score LBM^0.67 acumulado: ${viewModel.sessionLbmScore} • ELO proyectado: +${viewModel.projectedEloDelta}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: ApexTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetProgressionList() {
    final String unit = viewModel.unitSystem;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'PROGRESIÓN DE SERIES EN TIEMPO REAL',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: ApexTheme.textMuted,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 10),
            ...viewModel.sets.map((WorkoutSetModel s) {
              final double w = viewModel.displayWeight(
                s.completed
                    ? (s.actualWeightKg ?? s.prescribedWeightKg)
                    : s.prescribedWeightKg,
              );
              final int reps = s.completed
                  ? (s.actualReps ?? s.prescribedReps)
                  : s.prescribedReps;
              final double rpe = s.completed
                  ? (s.actualRpe ?? s.prescribedRpe)
                  : s.prescribedRpe;

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: s.completed
                      ? ApexTheme.readinessGreen.withValues(alpha: 0.2)
                      : ApexTheme.obsidianBg,
                  child: Icon(
                    s.completed ? Icons.check_rounded : Icons.fitness_center,
                    color: s.completed
                        ? ApexTheme.readinessGreen
                        : ApexTheme.textMuted,
                    size: 18,
                  ),
                ),
                title: Text(
                  '${s.exerciseName} • Serie #${s.setNumber}: $w $unit × $reps reps @ RPE ${rpe.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: s.completed
                        ? ApexTheme.textPrimary
                        : ApexTheme.textMuted,
                  ),
                ),
                subtitle: s.estimated1RmKg != null
                    ? Text(
                        'e1RM estimado: ${viewModel.displayWeight(s.estimated1RmKg!)} $unit',
                        style: const TextStyle(
                          fontSize: 12,
                          color: ApexTheme.voltAccent,
                        ),
                      )
                    : (s.aiRecalculated
                        ? const Text(
                            'Recalculado por Gemini Coach (temp=0.2)',
                            style: TextStyle(
                              fontSize: 11,
                              color: ApexTheme.cyanElectric,
                            ),
                          )
                        : null),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _openBinaryFeedbackModal(
    BuildContext context,
    WorkoutSetModel activeSet,
  ) async {
    final SetBinaryFeedbackResult? result =
        await showModalBottomSheet<SetBinaryFeedbackResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ApexTheme.cardGraphite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return SetBinaryFeedbackSheet(
          activeSet: activeSet,
          unitSystem: viewModel.unitSystem,
        );
      },
    );

    if (result != null) {
      await viewModel.submitSetBinaryFeedback(
        targetSet: activeSet,
        completedBinaryUi: result.completedBinaryUi,
        actualWeightKg: result.actualWeightKg,
        actualReps: result.actualReps,
        actualRpe: result.actualRpe,
      );
    }
  }

  void _openRoutineBuilderModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ApexTheme.cardGraphite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return _RoutineBuilderModalSheet(
          viewModel: viewModel,
          initialRoutine: viewModel.selectedRoutine,
        );
      },
    );
  }
}

class _RoutineBuilderModalSheet extends StatefulWidget {
  final LiveWorkoutViewModel viewModel;
  final RoutineTemplateModel? initialRoutine;

  const _RoutineBuilderModalSheet({
    required this.viewModel,
    this.initialRoutine,
  });

  @override
  State<_RoutineBuilderModalSheet> createState() =>
      _RoutineBuilderModalSheetState();
}

class _RoutineBuilderModalSheetState extends State<_RoutineBuilderModalSheet> {
  late int _dayOfWeek;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _focusCtrl;
  final List<_EditableExerciseDraft> _drafts = <_EditableExerciseDraft>[];

  @override
  void initState() {
    super.initState();
    final RoutineTemplateModel? r = widget.initialRoutine;
    _dayOfWeek = r?.dayOfWeek ?? DateTime.now().weekday;
    _nameCtrl = TextEditingController(
      text: r?.name ?? 'Pecho y Tríceps',
    );
    _focusCtrl = TextEditingController(
      text: r?.focusGroup ?? 'Pectoral / Tríceps',
    );

    if (r != null && r.exercises.isNotEmpty) {
      for (final RoutineExerciseItemModel ex in r.exercises) {
        _drafts.add(
          _EditableExerciseDraft(
            name: ex.exerciseName,
            muscleGroup: ex.muscleGroup,
            sets: ex.targetSets,
            reps: ex.targetReps,
            weightKg: ex.targetWeightKg,
          ),
        );
      }
    } else {
      _drafts.add(
        _EditableExerciseDraft(
          name: 'Barbell Bench Press',
          muscleGroup: 'Pecho',
          sets: 4,
          reps: 8,
          weightKg: 80.0,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _focusCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveRoutine() async {
    if (_nameCtrl.text.trim().isEmpty || _drafts.isEmpty) {
      return;
    }

    final List<Map<String, dynamic>> exercisesPayload = _drafts
        .where((_EditableExerciseDraft d) => d.nameCtrl.text.trim().isNotEmpty)
        .map((_EditableExerciseDraft d) {
      return <String, dynamic>{
        'exercise_name': d.nameCtrl.text.trim(),
        'muscle_group': d.muscleCtrl.text.trim().isEmpty
            ? 'General'
            : d.muscleCtrl.text.trim(),
        'category': 'hipertrofia',
        'target_sets': int.tryParse(d.setsCtrl.text.trim()) ?? 4,
        'target_reps': int.tryParse(d.repsCtrl.text.trim()) ?? 8,
        'target_weight_kg': double.tryParse(d.weightCtrl.text.trim()) ?? 60.0,
        'target_rpe': 8.0,
        'rest_seconds': 150,
      };
    }).toList();

    final bool ok = await widget.viewModel.saveCustomRoutineForDay(
      dayOfWeek: _dayOfWeek,
      name: _nameCtrl.text.trim(),
      focusGroup: _focusCtrl.text.trim(),
      exercises: exercisesPayload,
    );
    if (ok && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'CONFIGURAR RUTINA SEMANAL POR DÍA',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: ApexTheme.voltAccent,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _dayOfWeek,
              decoration: const InputDecoration(labelText: 'Día de la Semana'),
              items: const <DropdownMenuItem<int>>[
                DropdownMenuItem<int>(value: 1, child: Text('Día 1 - Lunes')),
                DropdownMenuItem<int>(value: 2, child: Text('Día 2 - Martes')),
                DropdownMenuItem<int>(
                    value: 3, child: Text('Día 3 - Miércoles')),
                DropdownMenuItem<int>(value: 4, child: Text('Día 4 - Jueves')),
                DropdownMenuItem<int>(value: 5, child: Text('Día 5 - Viernes')),
                DropdownMenuItem<int>(value: 6, child: Text('Día 6 - Sábado')),
                DropdownMenuItem<int>(value: 7, child: Text('Día 7 - Domingo')),
              ],
              onChanged: (int? v) {
                if (v != null) setState(() => _dayOfWeek = v);
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre (ej. Pecho y Tríceps)',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _focusCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Grupo Muscular',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'EJERCICIOS, SERIES, REPS Y PESO BASE (KG)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: ApexTheme.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            ..._drafts.asMap().entries.map((MapEntry<int, _EditableExerciseDraft> entry) {
              final int idx = entry.key;
              final _EditableExerciseDraft d = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: d.nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Ejercicio #${idx + 1}',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: d.setsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Series',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: d.repsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Reps',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: d.weightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Kg',
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: ApexTheme.deloadCrimson,
                        size: 18,
                      ),
                      onPressed: _drafts.length > 1
                          ? () => setState(() => _drafts.removeAt(idx))
                          : null,
                    ),
                  ],
                ),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _drafts.add(
                      _EditableExerciseDraft(
                        name: 'Nuevo Ejercicio',
                        muscleGroup: _focusCtrl.text.trim(),
                        sets: 4,
                        reps: 10,
                        weightKg: 50.0,
                      ),
                    );
                  });
                },
                icon: const Icon(Icons.add, color: ApexTheme.cyanElectric),
                label: const Text(
                  'Agregar Ejercicio al Día',
                  style: TextStyle(color: ApexTheme.cyanElectric),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: ApexTheme.voltAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed:
                  widget.viewModel.isSavingRoutine ? null : _saveRoutine,
              icon: const Icon(Icons.save_outlined),
              label: const Text(
                'GUARDAR RUTINA EN POSTGRESQL',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableExerciseDraft {
  final TextEditingController nameCtrl;
  final TextEditingController muscleCtrl;
  final TextEditingController setsCtrl;
  final TextEditingController repsCtrl;
  final TextEditingController weightCtrl;

  _EditableExerciseDraft({
    required String name,
    required String muscleGroup,
    required int sets,
    required int reps,
    required double weightKg,
  })  : nameCtrl = TextEditingController(text: name),
        muscleCtrl = TextEditingController(text: muscleGroup),
        setsCtrl = TextEditingController(text: sets.toString()),
        repsCtrl = TextEditingController(text: reps.toString()),
        weightCtrl = TextEditingController(text: weightKg.toStringAsFixed(1));
}

class _PrescriptionPillar extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _PrescriptionPillar({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: ApexTheme.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: accent,
          ),
        ),
      ],
    );
  }
}
