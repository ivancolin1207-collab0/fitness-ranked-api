import 'package:flutter/material.dart';
import '../../../../core/services/ble_heart_rate_service.dart';
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
            toolbarHeight: kToolbarHeight,
            titleSpacing: 12,
            title: const Text(
              'ENTRENO ADAPTATIVO',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900),
            ),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Vincular Monitor BLE (0x180D)',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: Icon(
                        viewModel.isBleConnected
                            ? Icons.bluetooth_connected_rounded
                            : Icons.bluetooth_searching_rounded,
                        color: viewModel.isBleConnected
                            ? ApexTheme.readinessGreen
                            : ApexTheme.cyanElectric,
                        size: 19,
                      ),
                      onPressed: () => _openBleHeartRateModal(context),
                    ),
                    IconButton(
                      tooltip: 'Configurar Rutina Semanal',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: const Icon(
                        Icons.calendar_month_outlined,
                        color: ApexTheme.cyanElectric,
                        size: 19,
                      ),
                      onPressed: () => _openRoutineBuilderModal(context),
                    ),
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 0,
                      ),
                      backgroundColor: ApexTheme.cardGraphite,
                      side: const BorderSide(color: ApexTheme.voltAccent),
                      label: Text(
                        viewModel.unitSystem,
                        style: const TextStyle(
                          color: ApexTheme.voltAccent,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      onPressed: viewModel.toggleUnitSystem,
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: viewModel.isLoadingPlan
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: viewModel.initializeWorkoutPlan,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (viewModel.errorMessage != null)
                              _buildErrorBanner(viewModel.errorMessage!),
                            if (viewModel.isRolloverActive &&
                                viewModel.rolloverBanner != null)
                              _buildRolloverAlertBanner(
                                viewModel.rolloverBanner!,
                              ),
                            _buildLiveTelemetryHeader(context),
                            const SizedBox(height: 10),
                            _buildWeeklyRoutinesSelector(context),
                            const SizedBox(height: 10),
                            _buildGeminiAdaptiveBanner(),
                            const SizedBox(height: 10),
                            if (!hasStartedSession)
                              _buildStartRoutineCard(context)
                            else if (activeSet != null)
                              _buildActiveSetCard(context, activeSet)
                            else
                              _buildSessionCompletedCard(),
                            if (hasStartedSession &&
                                viewModel.sets.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 10),
                              _buildSetProgressionList(),
                            ],
                          ],
                        ),
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ApexTheme.deloadCrimson.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ApexTheme.warningAmber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ApexTheme.warningAmber, width: 1.3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.event_repeat_rounded,
            color: ApexTheme.warningAmber,
            size: 20,
          ),
          const SizedBox(width: 8),
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
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ApexTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => _openRoutineBuilderModal(context),
                  icon: const Icon(
                    Icons.add_circle_outline,
                    size: 15,
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
            const SizedBox(height: 6),
            if (routines.isEmpty)
              const Text(
                'Aún no tienes rutinas configuradas. Pulsa "Editar / Crear Día" para armar tu semana.',
                style: TextStyle(fontSize: 12, color: ApexTheme.textMuted),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  spacing: 6,
                  children: routines.map((RoutineTemplateModel r) {
                    final bool isSelected = selected?.id == r.id;
                    return ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      selected: isSelected,
                      selectedColor: ApexTheme.voltAccent,
                      label: Text('${r.dayLabel}: ${r.name}'),
                      labelStyle: TextStyle(
                        color:
                            isSelected ? Colors.black : ApexTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                      onSelected: (_) => viewModel.selectRoutineTemplate(r),
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
          padding: const EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              const Icon(
                Icons.fitness_center_rounded,
                color: ApexTheme.voltAccent,
                size: 36,
              ),
              const SizedBox(height: 8),
              const Text(
                'CONFIGURA TU PRIMERA RUTINA SEMANAL',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: ApexTheme.voltAccent,
                  foregroundColor: Colors.black,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onPressed: () => _openRoutineBuilderModal(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'CREAR RUTINA POR DÍA',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final String unit = viewModel.unitSystem;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ApexTheme.voltAccent, width: 1.3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '${routine.dayLabel.toUpperCase()} • ${routine.name.toUpperCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Enfoque: ${routine.focusGroup} • ${routine.exercises.length} ejercicios con sobrecarga progresiva',
              style: const TextStyle(
                fontSize: 11.5,
                color: ApexTheme.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            if (routine.exercises.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Esta rutina aún no tiene ejercicios asignados. Edítala para añadir tus ejercicios.',
                  style: TextStyle(fontSize: 12, color: ApexTheme.textMuted),
                ),
              )
            else
              ...routine.exercises.map((RoutineExerciseItemModel ex) {
                final double w = viewModel.displayWeight(ex.targetWeightKg);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: ApexTheme.cyanElectric,
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ex.exerciseName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${ex.targetSets}×${ex.targetReps} @ $w $unit (RPE ${ex.targetRpe.toStringAsFixed(1)})',
                        style: const TextStyle(
                          color: ApexTheme.voltAccent,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: ApexTheme.voltAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed:
                  viewModel.isStartingWorkout || routine.exercises.isEmpty
                      ? null
                      : viewModel.startSelectedRoutine,
              icon: viewModel.isStartingWorkout
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text(
                'INICIAR SESIÓN EN VIVO (SOBRECARGA PROGRESIVA)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveTelemetryHeader(BuildContext context) {
    final bool isResting = viewModel.remainingRestSeconds > 0;
    final bool bleActive = viewModel.isBleConnected;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.timer_outlined,
                    size: 19,
                    color: isResting
                        ? ApexTheme.cyanElectric
                        : ApexTheme.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'DESCANSO',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: ApexTheme.textMuted,
                          ),
                        ),
                        Text(
                          viewModel.formattedRestTimer,
                          style: TextStyle(
                            fontSize: 17,
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
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _openBleHeartRateModal(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: bleActive
                      ? ApexTheme.readinessGreen.withValues(alpha: 0.14)
                      : ApexTheme.obsidianBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: bleActive
                        ? ApexTheme.readinessGreen
                        : ApexTheme.cyanElectric.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.favorite_rounded,
                      color: ApexTheme.deloadCrimson,
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${viewModel.liveHeartRate} BPM',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(
                      bleActive
                          ? Icons.bluetooth_connected_rounded
                          : Icons.bluetooth_rounded,
                      size: 15,
                      color: bleActive
                          ? ApexTheme.readinessGreen
                          : ApexTheme.cyanElectric,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: ApexTheme.voltAccent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ApexTheme.voltAccent),
              ),
              child: Text(
                '${viewModel.projectedEloDelta >= 0 ? "+" : ""}${viewModel.projectedEloDelta} ELO',
                style: const TextStyle(
                  color: ApexTheme.voltAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 11.5,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ApexTheme.cyanElectric.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
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
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'GEMINI COACH • ${viewModel.readinessZone}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: ApexTheme.cyanElectric,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  viewModel.geminiRationale,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ApexTheme.textPrimary,
                    height: 1.3,
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
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ApexTheme.voltAccent, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    activeSet.exerciseName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
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
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
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
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: ApexTheme.voltAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onPressed: viewModel.isSubmittingSet
                  ? null
                  : () => _openBinaryFeedbackModal(context, activeSet),
              icon: viewModel.isSubmittingSet
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.bolt_rounded, size: 19),
              label: const Text(
                'FINALIZAR SERIE',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
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
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            const Icon(
              Icons.emoji_events_rounded,
              color: ApexTheme.voltAccent,
              size: 40,
            ),
            const SizedBox(height: 8),
            const Text(
              '¡RUTINA DEL DÍA COMPLETADA Y GUARDADA EN RENDER!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Score LBM^0.67 acumulado: ${viewModel.sessionLbmScore} • ELO proyectado: +${viewModel.projectedEloDelta}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: ApexTheme.textMuted, fontSize: 12),
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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'PROGRESIÓN DE SERIES EN TIEMPO REAL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: ApexTheme.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
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
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 15,
                  backgroundColor: s.completed
                      ? ApexTheme.readinessGreen.withValues(alpha: 0.2)
                      : ApexTheme.obsidianBg,
                  child: Icon(
                    s.completed ? Icons.check_rounded : Icons.fitness_center,
                    color: s.completed
                        ? ApexTheme.readinessGreen
                        : ApexTheme.textMuted,
                    size: 16,
                  ),
                ),
                title: Text(
                  '${s.exerciseName} • Serie #${s.setNumber}: $w $unit × $reps reps @ RPE ${rpe.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: s.completed
                        ? ApexTheme.textPrimary
                        : ApexTheme.textMuted,
                  ),
                ),
                subtitle: s.estimated1RmKg != null
                    ? Text(
                        'e1RM estimado: ${viewModel.displayWeight(s.estimated1RmKg!)} $unit',
                        style: const TextStyle(
                          fontSize: 11,
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

  void _openBleHeartRateModal(BuildContext context) {
    viewModel.bleService.startScan();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ApexTheme.cardGraphite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return _BleHeartRateScannerModalSheet(
          bleService: viewModel.bleService,
        );
      },
    ).whenComplete(() {
      viewModel.bleService.stopScan();
    });
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

class _BleHeartRateScannerModalSheet extends StatelessWidget {
  final BleHeartRateService bleService;

  const _BleHeartRateScannerModalSheet({
    required this.bleService,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: bleService,
      builder: (BuildContext context, _) {
        final List<BleDiscoveredDevice> devices = bleService.discoveredDevices;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.bluetooth_searching_rounded,
                      color: ApexTheme.cyanElectric,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'BLUETOOTH BLE • MONITOR BPM EN VIVO (0x180D)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: ApexTheme.cyanElectric,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Reescanear',
                      icon: bleService.isScanning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: ApexTheme.voltAccent,
                              ),
                            )
                          : const Icon(
                              Icons.refresh_rounded,
                              color: ApexTheme.voltAccent,
                            ),
                      onPressed:
                          bleService.isScanning ? null : bleService.startScan,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Conecta tu Whoop (con "Broadcast Heart Rate" activo), banda Polar/Garmin o smartwatch compatible con GATT 0x180D / 0x2A37.',
                  style: TextStyle(fontSize: 11.5, color: ApexTheme.textMuted),
                ),
                if (bleService.statusMessage != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: ApexTheme.obsidianBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ApexTheme.cardBorder),
                    ),
                    child: Text(
                      bleService.statusMessage!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: ApexTheme.voltAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (bleService.isConnected) ...<Widget>[
                  const SizedBox(height: 10),
                  ListTile(
                    dense: true,
                    tileColor: ApexTheme.readinessGreen.withValues(alpha: 0.14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: ApexTheme.readinessGreen),
                    ),
                    leading: const Icon(
                      Icons.bluetooth_connected_rounded,
                      color: ApexTheme.readinessGreen,
                    ),
                    title: Text(
                      bleService.connectedDeviceName ?? 'Sensor Conectado',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      'Pulso actual: ${bleService.latestBpm ?? "--"} BPM (UINT8/UINT16 GATT 0x2A37)',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: ApexTheme.readinessGreen,
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: bleService.disconnect,
                      child: const Text(
                        'Desconectar',
                        style: TextStyle(color: ApexTheme.deloadCrimson),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (devices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: <Widget>[
                        Text(
                          bleService.isScanning
                              ? 'Escaneando sensores BLE cercanos (0x180D)...'
                              : 'No se detectaron sensores BLE transmitiendo cerca.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: ApexTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: devices.length,
                      itemBuilder: (BuildContext ctx, int idx) {
                        final BleDiscoveredDevice d = devices[idx];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            d.advertisesHrService
                                ? Icons.monitor_heart_rounded
                                : Icons.bluetooth_rounded,
                            color: d.advertisesHrService
                                ? ApexTheme.voltAccent
                                : ApexTheme.cyanElectric,
                          ),
                          title: Text(
                            d.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${d.advertisesHrService ? "GATT 0x180D • " : ""}RSSI ${d.rssi} dBm • ${d.remoteId}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: ApexTheme.textMuted,
                            ),
                          ),
                          trailing: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: ApexTheme.voltAccent,
                              foregroundColor: Colors.black,
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: bleService.isConnecting
                                ? null
                                : () async {
                                    final bool ok =
                                        await bleService.connectToDevice(d);
                                    if (ok && context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                            child: const Text(
                              'VINCULAR',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
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
      final double weightKg =
          double.tryParse(d.weightCtrl.text.trim()) ?? 60.0;
      return <String, dynamic>{
        'exercise_name': d.nameCtrl.text.trim(),
        'muscle_group': d.muscleCtrl.text.trim().isEmpty
            ? 'General'
            : d.muscleCtrl.text.trim(),
        'category': 'hipertrofia',
        'target_sets': int.tryParse(d.setsCtrl.text.trim()) ?? 4,
        'target_reps': int.tryParse(d.repsCtrl.text.trim()) ?? 8,
        'base_weight_kg': weightKg,
        'target_weight_kg': weightKg,
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
        top: 18,
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
              decoration: const InputDecoration(
                labelText: 'Día de la Semana',
                isDense: true,
              ),
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
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _focusCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Grupo Muscular',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'EJERCICIOS, SERIES, REPS Y PESO BASE (KG)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: ApexTheme.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            ..._drafts.asMap().entries.map(
                (MapEntry<int, _EditableExerciseDraft> entry) {
              final int idx = entry.key;
              final _EditableExerciseDraft d = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
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
                      visualDensity: VisualDensity.compact,
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
            const SizedBox(height: 10),
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
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: ApexTheme.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: accent,
          ),
        ),
      ],
    );
  }
}
