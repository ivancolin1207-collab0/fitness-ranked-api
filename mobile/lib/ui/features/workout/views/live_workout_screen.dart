import 'package:flutter/material.dart';
import '../../../../core/services/ble_heart_rate_service.dart';
import '../../../../core/services/exercise_media_service.dart';
import '../../../../data/models/workout_models.dart';
import '../../../core/app_theme.dart';
import '../../auth/view_models/auth_view_model.dart';
import '../../auth/views/profile_setup_screen.dart';
import '../view_models/live_workout_view_model.dart';
import 'set_binary_feedback_sheet.dart';

class LiveWorkoutScreen extends StatefulWidget {
  final LiveWorkoutViewModel viewModel;
  final AuthViewModel? authViewModel;
  final VoidCallback? onOpenTacticalCenter;
  final VoidCallback? onProfileOrBiometricsUpdated;

  const LiveWorkoutScreen({
    super.key,
    required this.viewModel,
    this.authViewModel,
    this.onOpenTacticalCenter,
    this.onProfileOrBiometricsUpdated,
  });

  @override
  State<LiveWorkoutScreen> createState() => _LiveWorkoutScreenState();
}

class _LiveWorkoutScreenState extends State<LiveWorkoutScreen> {
  LiveWorkoutViewModel get viewModel => widget.viewModel;

  String get _resolvedAthleteGender {
    final String raw =
        (widget.authViewModel?.currentUser?.sex ?? viewModel.athleteGender)
            .toLowerCase();
    return raw.contains('fem') ? 'female' : 'male';
  }

  @override
  void initState() {
    super.initState();
    viewModel.bleService.autoReconnectSavedDevice(
      userId: widget.authViewModel?.currentUser?.id,
    );
  }

  void _openCompleteBiometricsFlow(BuildContext context) {
    final AuthViewModel? authVm = widget.authViewModel;
    if (authVm == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => ProfileSetupScreen(
          viewModel: authVm,
          onCompleted: () {
            Navigator.of(ctx).pop();
            widget.onProfileOrBiometricsUpdated?.call();
          },
        ),
      ),
    );
  }

  Future<void> _handleRegenerateAiRoutine(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Gemini calculando 5 días de entrenamiento y cargas exactas según tus biometría...',
        ),
        duration: Duration(seconds: 3),
      ),
    );
    await viewModel.regenerateRoutineWithAi();
    final bool ok = viewModel.errorMessage == null;
    if (!context.mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ok ? ApexTheme.readinessGreen : ApexTheme.deloadCrimson,
        content: Text(
          ok
              ? 'Periodización de 5 días × 6 ejercicios generada por Gemini 2.5 Flash.'
              : (viewModel.errorMessage ??
                  'No se pudo regenerar la rutina con IA.'),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        viewModel,
        if (widget.authViewModel != null) widget.authViewModel!,
      ]),
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
                      tooltip: 'Regenerar Rutina 5 Días con Gemini IA',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: viewModel.isGeneratingAiRoutine
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: ApexTheme.voltAccent,
                              ),
                            )
                          : const Icon(
                              Icons.auto_awesome_rounded,
                              color: ApexTheme.voltAccent,
                              size: 19,
                            ),
                      onPressed: viewModel.isGeneratingAiRoutine
                          ? null
                          : () => _handleRegenerateAiRoutine(context),
                    ),
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
                    if (widget.onOpenTacticalCenter != null)
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 0,
                        ),
                        backgroundColor: ApexTheme.cardGraphite,
                        side: const BorderSide(color: ApexTheme.borderGraphite),
                        avatar: const Icon(
                          Icons.tune_rounded,
                          size: 13,
                          color: ApexTheme.textPrimary,
                        ),
                        label: const Text(
                          'CENTRO TÁCTICO',
                          style: TextStyle(
                            color: ApexTheme.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 9.5,
                          ),
                        ),
                        onPressed: widget.onOpenTacticalCenter,
                      ),
                  ],
                ),
              ),
            ],
          ),
          body: viewModel.isLoadingPlan
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const CircularProgressIndicator(
                          color: ApexTheme.voltAccent,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          viewModel.isGeneratingAiRoutine
                              ? 'Gemini calculando 5 días de entrenamiento y cargas exactas según tus biometría...'
                              : 'Sincronizando periodización cognitiva...',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ApexTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => viewModel.initializeWorkoutPlan(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 120),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (viewModel.isGeneratingAiRoutine)
                              _buildAiGeneratingOverlayBanner(),
                            if (viewModel.errorMessage != null)
                              _buildErrorBanner(viewModel.errorMessage!),
                            if (viewModel.isRolloverActive &&
                                viewModel.rolloverBanner != null)
                              _buildRolloverAlertBanner(
                                viewModel.rolloverBanner!,
                              ),
                            _buildLiveTelemetryHeader(context),
                            const SizedBox(height: 10),
                            if (viewModel.requiresBiometrics) ...<Widget>[
                              _buildRequiresBiometricsCard(context),
                            ] else ...<Widget>[
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
                            const SizedBox(height: 130),
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

  Widget _buildRequiresBiometricsCard(BuildContext context) {
    final List<String> missing = viewModel.missingBiometricFields;
    final String missingText = missing.isEmpty
        ? 'Peso corporal (kg), Estatura (cm) y Sexo biológico'
        : missing.join(', ');
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ApexTheme.warningAmber, width: 1.4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            const Icon(
              Icons.monitor_weight_outlined,
              color: ApexTheme.warningAmber,
              size: 40,
            ),
            const SizedBox(height: 10),
            const Text(
              'COMPLETA TU BIOMETRÍA REAL PARA CALCULAR TUS CARGAS',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'ApexMetrix no asigna rutinas ni pesos genéricos. Registra tu peso actual, estatura y sexo biológico ($missingText) para que Gemini 2.5 Flash prescriba tus 5 días × 6 ejercicios según tu Masa Magra (LBM).',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: ApexTheme.textMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            if (widget.authViewModel != null)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: ApexTheme.voltAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                onPressed: () => _openCompleteBiometricsFlow(context),
                icon: const Icon(Icons.manage_accounts_rounded, size: 18),
                label: const Text(
                  'COMPLETAR PESO, ESTATURA Y SEXO',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiGeneratingOverlayBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ApexTheme.voltAccent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ApexTheme.voltAccent, width: 1.3),
      ),
      child: const Row(
        children: <Widget>[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: ApexTheme.voltAccent,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Gemini calculando 5 días de entrenamiento y cargas exactas según tus biometría...',
              style: TextStyle(
                color: ApexTheme.voltAccent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
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
    final String aiTitle = viewModel.aiRoutineTitle;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'PERIODIZACIÓN IA • 5 DÍAS × 6 EJERCICIOS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: ApexTheme.voltAccent,
                          letterSpacing: 0.4,
                        ),
                      ),
                      if (aiTitle.trim().isNotEmpty)
                        Text(
                          aiTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: ApexTheme.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: viewModel.isGeneratingAiRoutine
                      ? null
                      : () => _handleRegenerateAiRoutine(context),
                  icon: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: ApexTheme.cyanElectric,
                  ),
                  label: const Text(
                    'REGENERAR RUTINA CON IA',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: ApexTheme.cyanElectric,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (routines.isEmpty)
              const Text(
                'Generando tu rutina personalizada de 5 días con Gemini 2.5 Flash...',
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
                    final String chipTitle = r.name
                            .toLowerCase()
                            .startsWith(r.dayLabel.toLowerCase())
                        ? r.name
                        : '${r.dayLabel}: ${r.name}';
                    return ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      selected: isSelected,
                      selectedColor: ApexTheme.voltAccent,
                      label: Text(chipTitle),
                      labelStyle: TextStyle(
                        color:
                            isSelected ? Colors.black : ApexTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                      onSelected: (_) {
                        setState(() {});
                        viewModel.selectRoutineTemplate(r);
                      },
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
                Icons.auto_awesome_rounded,
                color: ApexTheme.voltAccent,
                size: 36,
              ),
              const SizedBox(height: 8),
              const Text(
                'GENERAR PERIODIZACIÓN IA DE 5 DÍAS (6 EJERCICIOS POR DÍA)',
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
                onPressed: viewModel.isGeneratingAiRoutine
                    ? null
                    : () => _handleRegenerateAiRoutine(context),
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text(
                  'REGENERAR RUTINA CON IA',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final String unit = viewModel.unitSystem;
    final int safeIndex = routine.exercises.isEmpty
        ? 0
        : viewModel.selectedExerciseIndex.clamp(
            0,
            routine.exercises.length - 1,
          );
    final RoutineExerciseItemModel? currentExercise =
        routine.exercises.isNotEmpty ? routine.exercises[safeIndex] : null;

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
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    routine.name
                            .toLowerCase()
                            .startsWith(routine.dayLabel.toLowerCase())
                        ? routine.name.toUpperCase()
                        : '${routine.dayLabel.toUpperCase()} • ${routine.name.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: ApexTheme.cyanElectric.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: ApexTheme.cyanElectric.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Text(
                    '${routine.exercises.length} EJERCICIOS IA',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: ApexTheme.cyanElectric,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Enfoque: ${routine.focusGroup} • Cargas calculadas por LBM y recuperación',
              style: const TextStyle(
                fontSize: 11.5,
                color: ApexTheme.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            _buildExerciseQuickSwitcher(),
            const SizedBox(height: 10),
            BiomechanicalExerciseAvatarModule(
              key: ValueKey<String>(
                'preview_${safeIndex}_${currentExercise?.exerciseKey ?? ""}_${currentExercise?.exerciseName ?? ""}_$_resolvedAthleteGender',
              ),
              exerciseName: currentExercise != null
                  ? currentExercise.exerciseName
                  : routine.focusGroup,
              exerciseKey: currentExercise?.exerciseKey,
              athleteGender: _resolvedAthleteGender,
              onGenderChanged: null,
              lbmKg: viewModel.lbmKg,
              recoveryScore: viewModel.recoveryScore,
              targetReps: currentExercise?.targetReps ?? 10,
              targetRepsRange: currentExercise?.targetRepsRange,
              prescribedRpe: currentExercise?.targetRpe ?? 8.0,
              customTempo: currentExercise?.tempo,
              customCoachingCue: currentExercise?.coachingCue,
            ),
            const SizedBox(height: 12),
            const Text(
              'TOCA UN EJERCICIO PARA PREVISUALIZAR SU BIOMECÁNICA 3D/HD Y CARGA IA:',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: ApexTheme.textMuted,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            if (routine.exercises.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Esta rutina aún no tiene ejercicios asignados. Pulsa "REGENERAR RUTINA CON IA".',
                  style: TextStyle(fontSize: 12, color: ApexTheme.textMuted),
                ),
              )
            else
              ...routine.exercises.asMap().entries.map(
                  (MapEntry<int, RoutineExerciseItemModel> entry) {
                final int idx = entry.key;
                final RoutineExerciseItemModel ex = entry.value;
                final bool isSelectedEx = idx == safeIndex;
                final double w = viewModel.displayWeight(ex.targetWeightKg);
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    setState(() {});
                    viewModel.selectExercise(idx);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 7),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelectedEx
                          ? ApexTheme.voltAccent.withValues(alpha: 0.12)
                          : ApexTheme.obsidianBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelectedEx
                            ? ApexTheme.voltAccent
                            : ApexTheme.borderGraphite,
                        width: isSelectedEx ? 1.3 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isSelectedEx
                                    ? ApexTheme.voltAccent
                                    : ApexTheme.cardGraphite,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#${idx + 1}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: isSelectedEx
                                      ? Colors.black
                                      : ApexTheme.cyanElectric,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ex.exerciseName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${ex.targetSets}×${ex.targetRepsRange} @ ${w.toStringAsFixed(1)} $unit',
                              style: const TextStyle(
                                color: ApexTheme.voltAccent,
                                fontWeight: FontWeight.w900,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'RPE ${ex.targetRpe.toStringAsFixed(1)} • Tempo ${ex.tempo} • ${ex.coachingCue}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: ApexTheme.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 10),
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
                      '${viewModel.liveHeartRate ?? "--"} BPM',
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
        color: ApexTheme.cardGraphite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ApexTheme.borderGraphite,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.tune_rounded,
            color: ApexTheme.textPrimary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'DIRECTOR DE RENDIMIENTO • ${viewModel.readinessZone}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: ApexTheme.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  viewModel.geminiRationale,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ApexTheme.textMuted,
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

  Future<void> _promptCustomWeightDialog(
    BuildContext context,
    WorkoutSetModel activeSet,
  ) async {
    final String unit = viewModel.unitSystem;
    final double currentDisplayed =
        viewModel.displayWeight(activeSet.prescribedWeightKg);
    final TextEditingController ctrl = TextEditingController(
      text: currentDisplayed.toStringAsFixed(1),
    );
    final double? entered = await showDialog<double>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: ApexTheme.cardGraphite,
          title: Text(
            'AJUSTAR CARGA ($unit)',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: ApexTheme.voltAccent,
            ),
          ),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Peso de trabajo ($unit)',
              suffixText: unit,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ApexTheme.voltAccent,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                final double? parsed =
                    double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
                Navigator.of(dialogContext).pop(parsed);
              },
              child: const Text(
                'APLICAR',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );
    if (entered != null && entered > 0) {
      viewModel.updateActiveSetPrescribedWeight(activeSet, entered);
    }
  }

  Widget _buildExerciseQuickSwitcher() {
    final List<RoutineExerciseItemModel> exercises =
        viewModel.activeDayExercises;
    if (exercises.isEmpty) {
      return const SizedBox.shrink();
    }
    final int selectedExerciseIndex = viewModel.selectedExerciseIndex;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: exercises
            .asMap()
            .entries
            .map((MapEntry<int, RoutineExerciseItemModel> entry) {
          final int index = entry.key;
          final RoutineExerciseItemModel exercise = entry.value;
          final bool isSelected = selectedExerciseIndex == index;
          final bool isCompleted = viewModel.isExerciseCompleted(index);

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text('#${index + 1} ${exercise.exerciseName}'),
              selected: isSelected,
              selectedColor: const Color(0xFF1E232E),
              backgroundColor: const Color(0xFF14171E),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFFF59E0B)
                    : (isCompleted
                        ? const Color(0xFF10B981)
                        : const Color(0xFF2C3242)),
                width: isSelected ? 1.5 : 1.0,
              ),
              avatar: isCompleted
                  ? const Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Color(0xFF10B981),
                    )
                  : null,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              onSelected: (_) {
                setState(() {});
                // Actualiza el visor biomecánico y cargas al ejercicio tocado sin bloqueo lineal
                viewModel.selectExercise(index);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActiveSetCard(BuildContext context, WorkoutSetModel activeSet) {
    final String unit = viewModel.unitSystem;
    final double shownWeight =
        viewModel.displayWeight(activeSet.prescribedWeightKg);
    final int exIdx = viewModel.selectedExerciseIndex;
    final List<WorkoutSetModel> currentExSets =
        viewModel.setsForExercise(exIdx);
    final RoutineTemplateModel? routine = viewModel.selectedRoutine;
    final List<RoutineExerciseItemModel> dayExercises =
        viewModel.activeDayExercises;
    final RoutineExerciseItemModel? currentExercise =
        (exIdx >= 0 && exIdx < dayExercises.length)
            ? dayExercises[exIdx]
            : null;
    final String boundExerciseName =
        (currentExercise != null &&
                currentExercise.exerciseName.trim().isNotEmpty)
            ? currentExercise.exerciseName
            : activeSet.exerciseName;
    final String boundExerciseKey =
        (currentExercise != null &&
                currentExercise.exerciseKey.trim().isNotEmpty)
            ? currentExercise.exerciseKey
            : activeSet.exerciseKey;
    final String boundTempo =
        (currentExercise != null && currentExercise.tempo.trim().isNotEmpty)
            ? currentExercise.tempo
            : activeSet.tempo;
    final String boundCoachingCue =
        (currentExercise != null &&
                currentExercise.coachingCue.trim().isNotEmpty)
            ? currentExercise.coachingCue
            : activeSet.coachingCue;

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
            // Cabecera del día + Serie Activa
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (routine != null)
                        Text(
                          routine.name
                                  .toLowerCase()
                                  .startsWith(routine.dayLabel.toLowerCase())
                              ? routine.name.toUpperCase()
                              : '${routine.dayLabel.toUpperCase()} • ${routine.name.toUpperCase()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: ApexTheme.cyanElectric,
                            letterSpacing: 0.3,
                          ),
                        ),
                      Text(
                        '#${exIdx + 1} ${boundExerciseName.toUpperCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: activeSet.completed
                        ? const Color(0xFF10B981)
                        : ApexTheme.voltAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    activeSet.completed
                        ? 'SERIE #${activeSet.setNumber} ✓'
                        : 'SERIE ACTIVA #${activeSet.setNumber}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Selector Horizontal de Ejercicios (Exercise Quick Switcher - Libre sin bloqueo)
            _buildExerciseQuickSwitcher(),
            const SizedBox(height: 10),
            BiomechanicalExerciseAvatarModule(
              key: ValueKey<String>(
                'active_${exIdx}_${boundExerciseKey}_${boundExerciseName}_$_resolvedAthleteGender',
              ),
              exerciseName: boundExerciseName,
              exerciseKey: boundExerciseKey,
              athleteGender: _resolvedAthleteGender,
              onGenderChanged: null,
              lbmKg: viewModel.lbmKg,
              recoveryScore: viewModel.recoveryScore,
              targetReps: activeSet.prescribedReps,
              targetRepsRange: currentExercise?.targetRepsRange,
              prescribedRpe: activeSet.prescribedRpe,
              customTempo: boundTempo,
              customCoachingCue: boundCoachingCue,
            ),
            const SizedBox(height: 10),
            // Selector rápido de series de este ejercicio (muestra ejecutadas y pendientes)
            if (currentExSets.isNotEmpty) ...<Widget>[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: currentExSets.map((WorkoutSetModel s) {
                    final bool isCurrentSet = s.id == activeSet.id;
                    final double w = viewModel.displayWeight(
                      s.completed
                          ? (s.actualWeightKg ?? s.prescribedWeightKg)
                          : s.prescribedWeightKg,
                    );
                    final int reps = s.completed
                        ? (s.actualReps ?? s.prescribedReps)
                        : s.prescribedReps;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => viewModel.selectSet(s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrentSet
                                ? const Color(0xFF1E232E)
                                : const Color(0xFF14171E),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCurrentSet
                                  ? const Color(0xFFF59E0B)
                                  : (s.completed
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF2C3242)),
                              width: isCurrentSet ? 1.4 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                s.completed
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 13,
                                color: s.completed
                                    ? const Color(0xFF10B981)
                                    : (isCurrentSet
                                        ? const Color(0xFFF59E0B)
                                        : ApexTheme.textMuted),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'S#${s.setNumber}: ${w.toStringAsFixed(1)} $unit × $reps',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isCurrentSet
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isCurrentSet
                                      ? Colors.white
                                      : Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                Column(
                  children: <Widget>[
                    const Text(
                      'CARGA IA (EDITABLE)',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: ApexTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => viewModel.updateActiveSetPrescribedWeight(
                            activeSet,
                            (shownWeight - 2.5).clamp(2.5, 500.0),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: ApexTheme.obsidianBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: ApexTheme.borderGraphite),
                            ),
                            child: const Text(
                              '-2.5',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: ApexTheme.textMuted,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () =>
                              _promptCustomWeightDialog(context, activeSet),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '${shownWeight.toStringAsFixed(1)} $unit',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: ApexTheme.voltAccent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => viewModel.updateActiveSetPrescribedWeight(
                            activeSet,
                            (shownWeight + 2.5).clamp(2.5, 500.0),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: ApexTheme.obsidianBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: ApexTheme.voltAccent),
                            ),
                            child: const Text(
                              '+2.5',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: ApexTheme.voltAccent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
    final WorkoutSetModel? currentActive = viewModel.currentActiveSet;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'PROGRESIÓN DE SERIES EN TIEMPO REAL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: ApexTheme.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  'TOCA PARA PREVISUALIZAR / EDITAR',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...viewModel.sets.map((WorkoutSetModel s) {
              final bool isSelectedSet = currentActive?.id == s.id;
              final bool isSameExercise = currentActive != null &&
                  currentActive.exerciseName.toLowerCase().trim() ==
                      s.exerciseName.toLowerCase().trim();
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

              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => viewModel.selectSet(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelectedSet
                          ? const Color(0xFF1E232E)
                          : (isSameExercise
                              ? const Color(0xFF14171E)
                              : Colors.transparent),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelectedSet
                            ? const Color(0xFFF59E0B)
                            : (s.completed
                                ? const Color(0xFF10B981).withValues(alpha: 0.45)
                                : const Color(0xFF232834)),
                        width: isSelectedSet ? 1.4 : 1.0,
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 15,
                        backgroundColor: s.completed
                            ? ApexTheme.readinessGreen.withValues(alpha: 0.2)
                            : (isSelectedSet
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                                : ApexTheme.obsidianBg),
                        child: Icon(
                          s.completed
                              ? Icons.check_rounded
                              : Icons.fitness_center,
                          color: s.completed
                              ? ApexTheme.readinessGreen
                              : (isSelectedSet
                                  ? const Color(0xFFF59E0B)
                                  : ApexTheme.textMuted),
                          size: 16,
                        ),
                      ),
                      title: Text(
                        '${s.exerciseName} • Serie #${s.setNumber}: $w $unit × $reps reps @ RPE ${rpe.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontWeight: isSelectedSet
                              ? FontWeight.w900
                              : FontWeight.w700,
                          fontSize: 12.5,
                          color: isSelectedSet
                              ? Colors.white
                              : (s.completed
                                  ? ApexTheme.textPrimary
                                  : ApexTheme.textMuted),
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
                    ),
                  ),
                ),
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
          userId: widget.authViewModel?.currentUser?.id,
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
  final String? userId;

  const _BleHeartRateScannerModalSheet({
    required this.bleService,
    this.userId,
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
                        'BLUETOOTH BLE UNIVERSAL • MONITOR BPM (0x180D)',
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
                  'Compatible con Huawei Band/GT/Watch, Samsung Galaxy Watch, Polar, Garmin y Whoop 4.0 (GATT 0x180D / 0x2A37 • Reconexión Zero-Touch activa).',
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
                      onPressed: () => bleService.disconnect(
                        forgetDevice: true,
                        userId: userId,
                      ),
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
                              ? 'Buscando Huawei, Samsung, Garmin, Polar o Whoop cercanos...'
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
                            (d.advertisesHrService || d.isWearableBrand)
                                ? Icons.watch_rounded
                                : Icons.bluetooth_rounded,
                            color: (d.advertisesHrService || d.isWearableBrand)
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
                            '${d.advertisesHrService ? "GATT 0x180D • " : (d.isWearableBrand ? "Wearable BLE • " : "")}RSSI ${d.rssi} dBm • ${d.remoteId}',
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
                                        await bleService.connectToDevice(
                                      d,
                                      userId: userId,
                                    );
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
          name: '',
          muscleGroup: '',
          sets: 3,
          reps: 10,
          weightKg: 0.0,
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
          double.tryParse(d.weightCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
      return <String, dynamic>{
        'exercise_name': d.nameCtrl.text.trim(),
        'muscle_group': d.muscleCtrl.text.trim().isEmpty
            ? 'General'
            : d.muscleCtrl.text.trim(),
        'category': 'hipertrofia',
        'target_sets': int.tryParse(d.setsCtrl.text.trim()) ?? 3,
        'target_reps': int.tryParse(d.repsCtrl.text.trim()) ?? 10,
        'base_weight_kg': weightKg,
        'target_weight_kg': weightKg,
        'target_rpe': 8.0,
        'rest_seconds': 120,
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
                        name: '',
                        muscleGroup: _focusCtrl.text.trim(),
                        sets: 3,
                        reps: 10,
                        weightKg: 0.0,
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
