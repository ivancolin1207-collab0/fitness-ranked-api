import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../data/models/auth_models.dart';
import '../../../../data/models/biometric_models.dart';
import '../../../core/app_theme.dart';
import '../../auth/view_models/auth_view_model.dart';
import '../../auth/views/profile_setup_screen.dart';
import '../view_models/home_view_model.dart';

class HomeScreen extends StatelessWidget {
  final HomeViewModel viewModel;
  final AuthViewModel authViewModel;

  const HomeScreen({
    super.key,
    required this.viewModel,
    required this.authViewModel,
  });

  String _normalizedWearableSource(String raw) {
    if (raw == 'SAMSUNG_HEALTH' || raw == 'SAMSUNG_WATCH') {
      return 'SAMSUNG_WATCH';
    }
    if (raw == 'APPLE_WATCH') {
      return 'APPLE_WATCH';
    }
    if (raw == 'HUAWEI_GT') {
      return 'HUAWEI_GT';
    }
    return 'WHOOP';
  }

  String _wearableRegisterButtonText(String source) {
    switch (_normalizedWearableSource(source)) {
      case 'HUAWEI_GT':
        return 'REGISTRAR MÉTRICAS HUAWEI';
      case 'SAMSUNG_WATCH':
        return 'REGISTRAR MÉTRICAS SAMSUNG';
      case 'APPLE_WATCH':
        return 'REGISTRAR MÉTRICAS APPLE WATCH';
      case 'WHOOP':
      default:
        return 'REGISTRAR MÉTRICAS WHOOP';
    }
  }

  String _wearableBrandTitle(String source) {
    switch (_normalizedWearableSource(source)) {
      case 'HUAWEI_GT':
        return 'HUAWEI GT / WATCH';
      case 'SAMSUNG_WATCH':
        return 'SAMSUNG GALAXY WATCH';
      case 'APPLE_WATCH':
        return 'APPLE WATCH';
      case 'WHOOP':
      default:
        return 'WHOOP 4.0';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[viewModel, authViewModel]),
      builder: (BuildContext context, _) {
        final UserProfileModel? user = authViewModel.currentUser;
        final WearableMetricRecord? wearable = viewModel.wearable;
        final BiometricRecord? bio = viewModel.biometrics;
        final String activeSource =
            _normalizedWearableSource(viewModel.preferredWearable);

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: kToolbarHeight,
            titleSpacing: 12,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'BIOMETRÍA & READINESS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900),
                ),
                if (user != null)
                  Text(
                    '@${user.username} • ${user.fullName ?? "Atleta"} • ${user.trainingGoal}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: ApexTheme.cyanElectric,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: <Widget>[
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
                    IconButton(
                      tooltip: 'Editar Perfil',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: const Icon(
                        Icons.manage_accounts_outlined,
                        size: 19,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext ctx) => ProfileSetupScreen(
                              viewModel: authViewModel,
                              onCompleted: () => Navigator.of(ctx).pop(),
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'Servidor Cloud / IP',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: const Icon(
                        Icons.dns_outlined,
                        color: ApexTheme.cyanElectric,
                        size: 18,
                      ),
                      onPressed: () => _showServerInfoDialog(context),
                    ),
                    IconButton(
                      tooltip: 'Cerrar sesión',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: ApexTheme.textMuted,
                        size: 19,
                      ),
                      onPressed: authViewModel.logout,
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: viewModel.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: viewModel.initializeDashboard,
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
                              _buildAlertBanner(
                                viewModel.errorMessage!,
                                ApexTheme.deloadCrimson,
                              ),
                            if (viewModel.statusBanner != null)
                              _buildAlertBanner(
                                viewModel.statusBanner!,
                                (wearable != null &&
                                        (wearable.recoveryScore < 40.0 ||
                                            wearable.sleepEfficiencyPct < 70.0))
                                    ? ApexTheme.warningAmber
                                    : (wearable != null
                                        ? ApexTheme.readinessGreen
                                        : ApexTheme.cyanElectric),
                              ),
                            _buildWearableSourceBar(context, activeSource),
                            const SizedBox(height: 10),
                            if (wearable == null)
                              _buildWaitingWearableSyncCard(
                                context,
                                activeSource,
                              )
                            else ...<Widget>[
                              _buildPolymorphicWearableDashboard(
                                context,
                                wearable,
                                activeSource,
                              ),
                              const SizedBox(height: 10),
                              _buildWearableTelemetryRow(
                                wearable,
                                activeSource,
                              ),
                            ],
                            const SizedBox(height: 10),
                            _buildDualBiometricCaptureActions(context),
                            const SizedBox(height: 10),
                            if (bio != null)
                              _buildBodyCompositionCard(context, bio)
                            else
                              _buildEmptyBiometricsCard(context),
                            const SizedBox(height: 10),
                            _buildLbmTrendChartCard(),
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

  void _showServerInfoDialog(BuildContext context) {
    final TextEditingController ctrl = TextEditingController(
      text: authViewModel.apiBaseUrl,
    );
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: ApexTheme.cardGraphite,
          title: const Text(
            'Servidor Backend Activo',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'URL API (Render / Local)',
              isDense: true,
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
              onPressed: () async {
                await authViewModel.setServerUrl(ctrl.text.trim());
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAlertBanner(String text, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline_rounded, color: accent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWearableSourceBar(BuildContext context, String selectedSource) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.watch_rounded,
              color: ApexTheme.cyanElectric,
              size: 17,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'FUENTE WEARABLE:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: ApexTheme.textMuted,
                ),
              ),
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedSource,
                isDense: true,
                dropdownColor: ApexTheme.cardGraphite,
                style: const TextStyle(
                  color: ApexTheme.voltAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: 'WHOOP',
                    child: Text('WHOOP 4.0'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'HUAWEI_GT',
                    child: Text('HUAWEI GT / WATCH'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'SAMSUNG_WATCH',
                    child: Text('SAMSUNG GALAXY WATCH'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'APPLE_WATCH',
                    child: Text('APPLE WATCH'),
                  ),
                ],
                onChanged: (String? val) {
                  if (val != null) {
                    viewModel.setPreferredWearableSource(val);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingWearableSyncCard(
    BuildContext context,
    String activeSource,
  ) {
    final String brand = _wearableBrandTitle(activeSource);
    final String registerBtnText = _wearableRegisterButtonText(activeSource);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ApexTheme.cyanElectric, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: <Widget>[
            const Icon(
              Icons.sync_problem_rounded,
              color: ApexTheme.cyanElectric,
              size: 32,
            ),
            const SizedBox(height: 6),
            Text(
              'Sin telemetría de $brand sincronizada hoy',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                color: ApexTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sincroniza Health Connect o usa "$registerBtnText" para activar la prescripción adaptativa de Gemini Coach.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                color: ApexTheme.textMuted,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              spacing: 8,
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: ApexTheme.voltAccent,
                      foregroundColor: Colors.black,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: viewModel.isSyncingWearable
                        ? null
                        : viewModel.forceSyncWearable,
                    icon: viewModel.isSyncingWearable
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.sync_rounded, size: 16),
                    label: const Text(
                      'FORZAR SYNC',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ApexTheme.cyanElectric,
                      side: const BorderSide(color: ApexTheme.cyanElectric),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () =>
                        _openWearableManualSyncModal(context, activeSource),
                    icon: const Icon(Icons.bolt_rounded, size: 15),
                    label: Text(
                      registerBtnText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Renderiza polimórficamente el tablero del wearable seleccionado.
  Widget _buildPolymorphicWearableDashboard(
    BuildContext context,
    WearableMetricRecord wearable,
    String activeSource,
  ) {
    switch (activeSource) {
      case 'HUAWEI_GT':
        return _buildHuaweiGtCard(context, wearable);
      case 'SAMSUNG_WATCH':
        return _buildSamsungWatchCard(context, wearable);
      case 'APPLE_WATCH':
        return _buildAppleWatchCard(context, wearable);
      case 'WHOOP':
      default:
        return _buildWhoopOfficialCard(context, wearable);
    }
  }

  /// 1. Tarjeta Oficial WHOOP 4.0:
  /// - 3 Anillos Superiores: SUEÑO (%), RECUPERACIÓN (%), ESFUERZO (0-21)
  /// - Monitor de Salud (5/5 métricas) y Monitor de Estrés (0.0-3.0 Bajo/Medio/Alto)
  /// - Prescripción Cognitiva de Gemini por Sueño y Estrés
  Widget _buildWhoopOfficialCard(
    BuildContext context,
    WearableMetricRecord wearable,
  ) {
    final double sleepPct = wearable.sleepEfficiencyPct.clamp(0.0, 100.0);
    final double recovery = wearable.recoveryScore.clamp(0.0, 100.0);
    final double strain = wearable.strainScore.clamp(0.0, 21.0);
    final double stress = wearable.whoopStressLevel.clamp(0.0, 3.0);

    final bool isCompromised =
        recovery < 40.0 || sleepPct < 70.0 || stress >= 2.0;
    final Color recColor = recovery < 34.0
        ? ApexTheme.deloadCrimson
        : (recovery < 67.0 ? ApexTheme.warningAmber : ApexTheme.readinessGreen);

    final String stressCategory =
        stress >= 2.0 ? 'ALTO' : (stress >= 1.0 ? 'MEDIO' : 'BAJO');
    final Color stressColor = stress >= 2.0
        ? ApexTheme.warningAmber
        : (stress >= 1.0 ? ApexTheme.cyanElectric : ApexTheme.readinessGreen);

    final String geminiRationale = isCompromised
        ? 'Recuperación comprometida (${recovery.toStringAsFixed(0)}%) y estrés elevado. Redujimos el volumen prescrito para evitar fatiga del SNC.'
        : (recovery >= 80.0
            ? 'Recuperación óptima (${recovery.toStringAsFixed(0)}%). Gemini Coach activa sobrecarga progresiva (+2.5 kg).'
            : 'Recuperación estable (${recovery.toStringAsFixed(0)}%). Gemini Coach mantiene volumen objetivo.');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Cabecera WHOOP + Badge de Zona
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text(
                  'WHOOP 4.0 • TELEMETRÍA DIARIA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: ApexTheme.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (isCompromised ? ApexTheme.deloadCrimson : recColor)
                        .withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isCompromised
                        ? 'ZONA ROJA • DELOAD (-20% CARGA)'
                        : (recovery >= 67.0
                            ? 'ZONA VERDE • SOBRECARGA'
                            : 'ZONA AMARILLA • MANTENIMIENTO'),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: isCompromised ? ApexTheme.deloadCrimson : recColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // 3 Anillos Oficiales Whoop: SUEÑO %, RECUPERACIÓN %, ESFUERZO
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                _WhoopCircleGauge(
                  label: 'SUEÑO >',
                  valueText: '${sleepPct.toStringAsFixed(0)}%',
                  progress: (sleepPct / 100.0).clamp(0.0, 1.0),
                  color: const Color(0xFF75A8D3),
                ),
                _WhoopCircleGauge(
                  label: 'RECUPERACIÓN >',
                  valueText: '${recovery.toStringAsFixed(0)}%',
                  progress: (recovery / 100.0).clamp(0.0, 1.0),
                  color: recColor,
                ),
                _WhoopCircleGauge(
                  label: 'ESFUERZO >',
                  valueText: strain.toStringAsFixed(1),
                  progress: (strain / 21.0).clamp(0.0, 1.0),
                  color: const Color(0xFF0095FF),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Tarjetas duales: MONITOR DE SALUD y MONITOR DE ESTRÉS
            Row(
              spacing: 10,
              children: <Widget>[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ApexTheme.obsidianBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ApexTheme.readinessGreen.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'MONITOR DE SALUD',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: ApexTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: ApexTheme.readinessGreen
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 13,
                                color: ApexTheme.readinessGreen,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Text(
                                    'DENTRO DEL RANGO',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      color: ApexTheme.readinessGreen,
                                    ),
                                  ),
                                  Text(
                                    '${wearable.whoopHealthMetricsInRange}/5 métricas',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: ApexTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ApexTheme.obsidianBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: stressColor.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'MONITOR DE ESTRÉS',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: ApexTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: stressColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                stress.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: stressColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    stressCategory,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: stressColor,
                                    ),
                                  ),
                                  const Text(
                                    'Escala 0.0–3.0',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: ApexTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Racional Cognitivo de Gemini Coach
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: ApexTheme.obsidianBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCompromised
                      ? ApexTheme.deloadCrimson.withValues(alpha: 0.6)
                      : ApexTheme.cyanElectric.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: isCompromised
                        ? ApexTheme.deloadCrimson
                        : ApexTheme.cyanElectric,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      geminiRationale,
                      style: const TextStyle(
                        fontSize: 11.2,
                        color: ApexTheme.textPrimary,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _buildWearableCardActionFooter(context, 'WHOOP'),
          ],
        ),
      ),
    );
  }

  /// 2. Tarjeta HUAWEI GT / WATCH (Cero menciones a Whoop):
  /// - Nivel de Estrés (0-100), Puntuación TruSleep, Frecuencia Cardíaca Media y VO2Max
  Widget _buildHuaweiGtCard(
    BuildContext context,
    WearableMetricRecord wearable,
  ) {
    final int stress = wearable.huaweiStressScore.clamp(1, 100);
    final int truSleep = wearable.huaweiTruSleepScore.clamp(1, 100);
    final int avgHr = wearable.avgHr;
    final double vo2Max = wearable.huaweiVo2Max;
    final bool isHighStress = stress >= 68 || truSleep < 70;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text(
                  'HUAWEI HEALTH • GT TELEMETRY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.9,
                    color: ApexTheme.cyanElectric,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (isHighStress
                            ? ApexTheme.deloadCrimson
                            : ApexTheme.readinessGreen)
                        .withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isHighStress
                        ? 'DESCARGA ACTIVA (-15% CARGA)'
                        : 'ESTADO FISIOLÓGICO ÓPTIMO',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: isHighStress
                          ? ApexTheme.deloadCrimson
                          : ApexTheme.readinessGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              spacing: 8,
              children: <Widget>[
                Expanded(
                  child: _DeviceKpiBox(
                    title: 'NIVEL DE ESTRÉS',
                    value: '$stress / 100',
                    subtitle: stress >= 68 ? 'Elevado' : 'Normal (Calma)',
                    accent: stress >= 68
                        ? ApexTheme.warningAmber
                        : ApexTheme.cyanElectric,
                  ),
                ),
                Expanded(
                  child: _DeviceKpiBox(
                    title: 'PUNTUACIÓN TRUSLEEP',
                    value: '$truSleep pts',
                    subtitle: '${wearable.sleepHours.toStringAsFixed(1)} h sueño',
                    accent: ApexTheme.readinessGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              spacing: 8,
              children: <Widget>[
                Expanded(
                  child: _DeviceKpiBox(
                    title: 'FC MEDIA DIARIA',
                    value: '$avgHr bpm',
                    subtitle: 'Reposo: ${wearable.restingHr} bpm',
                    accent: ApexTheme.voltAccent,
                  ),
                ),
                Expanded(
                  child: _DeviceKpiBox(
                    title: 'VO2MAX ESTIMADO',
                    value: '${vo2Max.toStringAsFixed(1)} ml/kg',
                    subtitle: 'Capacidad aeróbica',
                    accent: ApexTheme.cyanElectric,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildWearableCardActionFooter(context, 'HUAWEI_GT'),
          ],
        ),
      ),
    );
  }

  /// 3. Tarjeta SAMSUNG GALAXY WATCH (Cero menciones a Whoop):
  /// - Puntuación de Energía (Energy Score), Tiempo de Sueño y Composición Corporal BIA
  Widget _buildSamsungWatchCard(
    BuildContext context,
    WearableMetricRecord wearable,
  ) {
    final int energyScore = wearable.samsungEnergyScore.clamp(1, 100);
    final Color scoreColor = ApexTheme.readinessColor(energyScore.toDouble());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text(
                  'SAMSUNG GALAXY WATCH • BIOACTIVE SENSOR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                    color: ApexTheme.cyanElectric,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ENERGY SCORE $energyScore',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: scoreColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              spacing: 8,
              children: <Widget>[
                Expanded(
                  child: _DeviceKpiBox(
                    title: 'PUNTUACIÓN DE ENERGÍA',
                    value: '$energyScore / 100',
                    subtitle: energyScore < 45
                        ? 'Descarga sugerida por Gemini'
                        : 'Listo para sobrecarga',
                    accent: scoreColor,
                  ),
                ),
                Expanded(
                  child: _DeviceKpiBox(
                    title: 'TIEMPO DE SUEÑO',
                    value: '${wearable.sleepHours.toStringAsFixed(1)} h',
                    subtitle:
                        'Eficiencia: ${wearable.sleepEfficiencyPct.toStringAsFixed(0)}%',
                    accent: ApexTheme.cyanElectric,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _DeviceKpiBox(
              title: 'COMPOSICIÓN CORPORAL BIA (GALAXY SENSOR)',
              value:
                  'Músculo Esquelético: ${wearable.samsungBiaMusclePct.toStringAsFixed(1)}%  •  Grasa BIA: ${wearable.samsungBiaFatPct.toStringAsFixed(1)}%',
              subtitle:
                  'Sincronizado con índice alométrico LBM^0.67 y Gemini Coach',
              accent: ApexTheme.voltAccent,
            ),
            const SizedBox(height: 10),
            _buildWearableCardActionFooter(context, 'SAMSUNG_WATCH'),
          ],
        ),
      ),
    );
  }

  /// 4. Tarjeta APPLE WATCH (Cero menciones a Whoop):
  /// - 3 Anillos (Moverse kcal, Ejercicio min, De Pie h) y Variabilidad HRV
  Widget _buildAppleWatchCard(
    BuildContext context,
    WearableMetricRecord wearable,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'APPLE WATCH • ANILLOS DE ACTIVIDAD & HRV',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                    color: ApexTheme.textPrimary,
                  ),
                ),
                Icon(
                  Icons.watch_outlined,
                  size: 16,
                  color: ApexTheme.voltAccent,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                _WhoopCircleGauge(
                  label: 'MOVERSE',
                  valueText: '${wearable.appleMoveKcal} kcal',
                  progress: (wearable.appleMoveKcal / 800.0).clamp(0.0, 1.0),
                  color: const Color(0xFFFA114F),
                ),
                _WhoopCircleGauge(
                  label: 'EJERCICIO',
                  valueText: '${wearable.appleExerciseMinutes} min',
                  progress:
                      (wearable.appleExerciseMinutes / 60.0).clamp(0.0, 1.0),
                  color: const Color(0xFF92E82A),
                ),
                _WhoopCircleGauge(
                  label: 'DE PIE',
                  valueText: '${wearable.appleStandHours} h',
                  progress: (wearable.appleStandHours / 12.0).clamp(0.0, 1.0),
                  color: const Color(0xFF00D9FF),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DeviceKpiBox(
              title: 'VARIABILIDAD HRV (SDNN / RMSSD)',
              value: '${wearable.hrvMs.toStringAsFixed(0)} ms',
              subtitle:
                  'FC en reposo: ${wearable.restingHr} bpm • Sueño: ${wearable.sleepHours.toStringAsFixed(1)} h',
              accent: ApexTheme.cyanElectric,
            ),
            const SizedBox(height: 10),
            _buildWearableCardActionFooter(context, 'APPLE_WATCH'),
          ],
        ),
      ),
    );
  }

  Widget _buildWearableCardActionFooter(
    BuildContext context,
    String activeSource,
  ) {
    final String registerBtnText = _wearableRegisterButtonText(activeSource);
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            foregroundColor: ApexTheme.voltAccent,
            side: const BorderSide(color: ApexTheme.voltAccent),
          ),
          onPressed:
              viewModel.isSyncingWearable ? null : viewModel.forceSyncWearable,
          icon: const Icon(Icons.sync_rounded, size: 14),
          label: const Text(
            'FORZAR SYNC',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900),
          ),
        ),
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            backgroundColor: ApexTheme.cyanElectric.withValues(alpha: 0.16),
            foregroundColor: ApexTheme.cyanElectric,
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          onPressed: () =>
              _openWearableManualSyncModal(context, activeSource),
          icon: const Icon(Icons.tune_rounded, size: 14),
          label: Text(
            registerBtnText,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWearableTelemetryRow(
    WearableMetricRecord wearable,
    String activeSource,
  ) {
    return Row(
      spacing: 8,
      children: <Widget>[
        Expanded(
          child: _MetricTile(
            label: 'HRV (RMSSD)',
            value: '${wearable.hrvMs.toStringAsFixed(0)} ms',
            accent: ApexTheme.voltAccent,
            icon: Icons.monitor_heart_outlined,
          ),
        ),
        Expanded(
          child: _MetricTile(
            label: 'FC REPOSO',
            value: '${wearable.restingHr} bpm',
            accent: ApexTheme.cyanElectric,
            icon: Icons.favorite_border_rounded,
          ),
        ),
        Expanded(
          child: _MetricTile(
            label: activeSource == 'WHOOP' ? 'SUEÑO (%)' : 'SUEÑO (H)',
            value: activeSource == 'WHOOP'
                ? '${wearable.sleepEfficiencyPct.toStringAsFixed(0)}%'
                : '${wearable.sleepHours.toStringAsFixed(1)} h',
            accent: ApexTheme.readinessGreen,
            icon: Icons.bedtime_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildDualBiometricCaptureActions(BuildContext context) {
    return Row(
      spacing: 8,
      children: <Widget>[
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: ApexTheme.cardGraphite,
              foregroundColor: ApexTheme.voltAccent,
              side: const BorderSide(color: ApexTheme.voltAccent),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(vertical: 11),
            ),
            onPressed: () => _openBiometricFormModal(context, null),
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: const Text(
              'CAPTURA MANUAL',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5),
            ),
          ),
        ),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: ApexTheme.voltAccent,
              foregroundColor: Colors.black,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(vertical: 11),
            ),
            onPressed: viewModel.isScanningOcr
                ? null
                : () => _showOcrSourcePicker(context),
            icon: viewModel.isScanningOcr
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(Icons.document_scanner_rounded, size: 17),
            label: Text(
              viewModel.isScanningOcr ? 'ESCANEANDO...' : 'ESCANEAR FITDAYS',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyBiometricsCard(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.monitor_weight_outlined,
              color: ApexTheme.voltAccent,
              size: 32,
            ),
            SizedBox(height: 6),
            Text(
              'SIN REGISTROS DE COMPOSICIÓN CORPORAL',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              'Usa "Captura Manual" o "Escanear Fitdays" (JPEG 90 • Gemini Vision) para registrar peso, % grasa, masa muscular y BMR en PostgreSQL.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: ApexTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyCompositionCard(BuildContext context, BiometricRecord bio) {
    final String unit = viewModel.unitSystem;
    final double displayWeight = viewModel.formatMass(bio.weightKg);
    final double displayLbm = viewModel.formatMass(bio.leanBodyMassKg);
    final double displayMuscle = viewModel.formatMass(bio.muscleMassKg);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'COMPOSICIÓN CORPORAL (${bio.sourceProvider})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: ApexTheme.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: ApexTheme.voltAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'LBM^0.67 ACTIVO',
                    style: TextStyle(
                      fontSize: 10,
                      color: ApexTheme.voltAccent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 10,
              children: <Widget>[
                _BioStatItem(
                  label: 'PESO TOTAL',
                  value: '$displayWeight $unit',
                ),
                _BioStatItem(
                  label: 'MASA MAGRA (LBM)',
                  value: '$displayLbm $unit',
                  highlight: true,
                ),
                _BioStatItem(
                  label: '% GRASA CORPORAL',
                  value: '${bio.fatPercentage.toStringAsFixed(1)}%',
                ),
                _BioStatItem(
                  label: 'MASA MUSCULAR',
                  value: '$displayMuscle $unit',
                ),
                _BioStatItem(
                  label: 'MÚSCULO ESQUELÉTICO',
                  value: '${bio.skeletalMusclePct.toStringAsFixed(1)}%',
                ),
                _BioStatItem(
                  label: 'GRASA VISCERAL',
                  value: 'Nivel ${bio.visceralFat}',
                ),
                _BioStatItem(
                  label: 'AGUA CORPORAL',
                  value: '${bio.bodyWaterPct.toStringAsFixed(1)}%',
                ),
                _BioStatItem(
                  label: 'BMR (METABOLISMO)',
                  value: '${bio.bmr} kcal',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLbmTrendChartCard() {
    final List<BiometricRecord> history =
        viewModel.biometricsHistory.reversed.toList();
    final List<FlSpot> spots = <FlSpot>[];
    for (int i = 0; i < history.length; i++) {
      spots.add(FlSpot((i + 1).toDouble(), history[i].leanBodyMassKg));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'HISTORIAL REAL DE MASA MAGRA (LBM KG • POSTGRESQL)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: ApexTheme.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            if (spots.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    'Registra tu primera captura biométrica para graficar tu tendencia real.',
                    style: TextStyle(color: ApexTheme.textMuted, fontSize: 12),
                  ),
                ),
              )
            else
              SizedBox(
                height: 125,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: <LineChartBarData>[
                      LineChartBarData(
                        isCurved: true,
                        color: ApexTheme.voltAccent,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: ApexTheme.voltAccent.withValues(alpha: 0.12),
                        ),
                        spots: spots.length == 1
                            ? <FlSpot>[
                                FlSpot(0, spots.first.y),
                                spots.first,
                              ]
                            : spots,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showOcrSourcePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ApexTheme.cardGraphite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'ESCANEAR REPORTE DE BIOIMPEDANCIA FITDAYS',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'La imagen se transcodifica automáticamente a JPEG (calidad 90 • image/jpeg) para Gemini Vision.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: ApexTheme.textMuted),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: ApexTheme.voltAccent,
                  ),
                  title: const Text('Seleccionar Screenshot de Galería'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    final FitdaysExtractedMetricsModel? extracted =
                        await viewModel.scanFitdaysForFormPrefill(
                      ImageSource.gallery,
                    );
                    if (extracted != null && context.mounted) {
                      _openBiometricFormModal(context, extracted);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_outlined,
                    color: ApexTheme.cyanElectric,
                  ),
                  title: const Text('Capturar con Cámara'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    final FitdaysExtractedMetricsModel? extracted =
                        await viewModel.scanFitdaysForFormPrefill(
                      ImageSource.camera,
                    );
                    if (extracted != null && context.mounted) {
                      _openBiometricFormModal(context, extracted);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openBiometricFormModal(
    BuildContext context,
    FitdaysExtractedMetricsModel? prefilled,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ApexTheme.cardGraphite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return _BiometricCaptureModalSheet(
          viewModel: viewModel,
          prefilled: prefilled,
          latestRecord: viewModel.biometrics,
        );
      },
    );
  }

  void _openWearableManualSyncModal(BuildContext context, String activeSource) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ApexTheme.cardGraphite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return _WearablePolymorphicSyncModalSheet(
          viewModel: viewModel,
          activeSource: activeSource,
        );
      },
    );
  }
}

class _WhoopCircleGauge extends StatelessWidget {
  final String label;
  final String valueText;
  final double progress;
  final Color color;

  const _WhoopCircleGauge({
    required this.label,
    required this.valueText,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 78,
          height: 78,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              SizedBox(
                width: 74,
                height: 74,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.05, 1.0),
                  strokeWidth: 6.5,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Text(
                valueText,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  color: ApexTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: ApexTheme.textMuted,
          ),
        ),
      ],
    );
  }
}

class _DeviceKpiBox extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color accent;

  const _DeviceKpiBox({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ApexTheme.obsidianBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: ApexTheme.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10.5,
              color: ApexTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BiometricCaptureModalSheet extends StatefulWidget {
  final HomeViewModel viewModel;
  final FitdaysExtractedMetricsModel? prefilled;
  final BiometricRecord? latestRecord;

  const _BiometricCaptureModalSheet({
    required this.viewModel,
    this.prefilled,
    this.latestRecord,
  });

  @override
  State<_BiometricCaptureModalSheet> createState() =>
      _BiometricCaptureModalSheetState();
}

class _BiometricCaptureModalSheetState
    extends State<_BiometricCaptureModalSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _weightCtrl;
  late final TextEditingController _fatPctCtrl;
  late final TextEditingController _muscleKgCtrl;
  late final TextEditingController _skeletalPctCtrl;
  late final TextEditingController _visceralCtrl;
  late final TextEditingController _waterPctCtrl;
  late final TextEditingController _bmrCtrl;

  @override
  void initState() {
    super.initState();
    final FitdaysExtractedMetricsModel? p = widget.prefilled;
    final BiometricRecord? latest = widget.latestRecord;

    _weightCtrl = TextEditingController(
      text: p != null
          ? p.weightKg.toStringAsFixed(1)
          : (latest != null ? latest.weightKg.toStringAsFixed(1) : '78.0'),
    );
    _fatPctCtrl = TextEditingController(
      text: p != null
          ? p.fatPercentage.toStringAsFixed(1)
          : (latest != null ? latest.fatPercentage.toStringAsFixed(1) : '14.5'),
    );
    _muscleKgCtrl = TextEditingController(
      text: p != null
          ? p.muscleMassKg.toStringAsFixed(1)
          : (latest != null ? latest.muscleMassKg.toStringAsFixed(1) : '63.2'),
    );
    _skeletalPctCtrl = TextEditingController(
      text: p != null
          ? p.skeletalMusclePct.toStringAsFixed(1)
          : (latest != null
              ? latest.skeletalMusclePct.toStringAsFixed(1)
              : '43.0'),
    );
    _visceralCtrl = TextEditingController(
      text: p != null
          ? p.visceralFat.toString()
          : (latest != null ? latest.visceralFat.toString() : '6'),
    );
    _waterPctCtrl = TextEditingController(
      text: p != null
          ? p.bodyWaterPct.toStringAsFixed(1)
          : (latest != null ? latest.bodyWaterPct.toStringAsFixed(1) : '61.5'),
    );
    _bmrCtrl = TextEditingController(
      text: p != null
          ? p.bmr.toString()
          : (latest != null ? latest.bmr.toString() : '1820'),
    );
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _fatPctCtrl.dispose();
    _muscleKgCtrl.dispose();
    _skeletalPctCtrl.dispose();
    _visceralCtrl.dispose();
    _waterPctCtrl.dispose();
    _bmrCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final FitdaysExtractedMetricsModel payload = FitdaysExtractedMetricsModel(
      weightKg: double.parse(_weightCtrl.text.trim()),
      fatPercentage: double.parse(_fatPctCtrl.text.trim()),
      muscleMassKg: double.parse(_muscleKgCtrl.text.trim()),
      skeletalMusclePct: double.parse(_skeletalPctCtrl.text.trim()),
      visceralFat: int.parse(_visceralCtrl.text.trim()),
      bodyWaterPct: double.parse(_waterPctCtrl.text.trim()),
      bmr: int.parse(_bmrCtrl.text.trim()),
      ocrConfidence: widget.prefilled?.ocrConfidence ?? 1.0,
      sourceProvider: widget.prefilled != null ? 'FITDAYS_OCR' : 'MANUAL_FORM',
    );

    final bool saved = await widget.viewModel.saveBiometricsRecord(payload);
    if (saved && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isOcrReview = widget.prefilled != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                isOcrReview
                    ? 'REVISAR REPORTE FITDAYS EXTRAÍDO POR GEMINI'
                    : 'REGISTRO MANUAL DE BIOIMPEDANCIA',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: ApexTheme.voltAccent,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Verifica los 7 indicadores biométricos antes de guardar en Render PostgreSQL.',
                style: TextStyle(fontSize: 12, color: ApexTheme.textMuted),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _buildNumberField(
                      controller: _weightCtrl,
                      label: 'Peso (kg)',
                      min: 30,
                      max: 280,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildNumberField(
                      controller: _fatPctCtrl,
                      label: 'Grasa Corporal (%)',
                      min: 2.5,
                      max: 65,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _buildNumberField(
                      controller: _muscleKgCtrl,
                      label: 'Masa Muscular (kg)',
                      min: 15,
                      max: 160,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildNumberField(
                      controller: _skeletalPctCtrl,
                      label: 'Músculo Esquelético (%)',
                      min: 15,
                      max: 75,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _buildNumberField(
                      controller: _visceralCtrl,
                      label: 'Grasa Visceral (1-60)',
                      min: 1,
                      max: 60,
                      isInteger: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildNumberField(
                      controller: _waterPctCtrl,
                      label: 'Agua Corporal (%)',
                      min: 30,
                      max: 85,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildNumberField(
                controller: _bmrCtrl,
                label: 'BMR / Metabolismo Basal (kcal)',
                min: 800,
                max: 5500,
                isInteger: true,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: ApexTheme.voltAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed:
                    widget.viewModel.isSavingBiometrics ? null : _submit,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text(
                  'GUARDAR EN POSTGRESQL (RENDER)',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required double min,
    required double max,
    bool isInteger = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: !isInteger),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: ApexTheme.obsidianBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: (String? v) {
        final String raw = (v ?? '').trim();
        final double? val = double.tryParse(raw);
        if (val == null || val < min || val > max) {
          return '${min.toStringAsFixed(isInteger ? 0 : 1)} - ${max.toStringAsFixed(isInteger ? 0 : 1)}';
        }
        return null;
      },
    );
  }
}

/// Modal Polimórfico de Captura Rápida de Métricas según el Wearable activo
/// (WHOOP 4.0, HUAWEI GT, SAMSUNG GALAXY WATCH, APPLE WATCH).
class _WearablePolymorphicSyncModalSheet extends StatefulWidget {
  final HomeViewModel viewModel;
  final String activeSource;

  const _WearablePolymorphicSyncModalSheet({
    required this.viewModel,
    required this.activeSource,
  });

  @override
  State<_WearablePolymorphicSyncModalSheet> createState() =>
      _WearablePolymorphicSyncModalSheetState();
}

class _WearablePolymorphicSyncModalSheetState
    extends State<_WearablePolymorphicSyncModalSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Campos compartidos / Whoop
  late double _recoverySlider;
  late double _strainSlider;
  late double _whoopSleepPctSlider;
  late double _whoopStressSlider;
  late final TextEditingController _hrvCtrl;
  late final TextEditingController _rhrCtrl;
  late final TextEditingController _sleepHoursCtrl;

  // Campos Huawei GT
  late final TextEditingController _huaweiStressCtrl;
  late final TextEditingController _huaweiTruSleepCtrl;
  late final TextEditingController _huaweiAvgHrCtrl;
  late final TextEditingController _huaweiVo2MaxCtrl;

  // Campos Samsung Watch
  late final TextEditingController _samsungEnergyCtrl;
  late final TextEditingController _samsungMusclePctCtrl;
  late final TextEditingController _samsungFatPctCtrl;

  // Campos Apple Watch
  late final TextEditingController _appleMoveKcalCtrl;
  late final TextEditingController _appleExerciseMinCtrl;
  late final TextEditingController _appleStandHoursCtrl;

  @override
  void initState() {
    super.initState();
    final WearableMetricRecord? w = widget.viewModel.wearable;
    // Pre-llenado con los valores reales del Whoop del atleta (35% Rec, 9.6 Strain, 72% Sueño, 2.2 Estrés)
    _recoverySlider = (w?.recoveryScore ?? 35.0).clamp(0.0, 100.0);
    _strainSlider = (w?.strainScore ?? 9.6).clamp(0.0, 21.0);
    _whoopSleepPctSlider = (w?.sleepEfficiencyPct ?? 72.0).clamp(0.0, 100.0);
    _whoopStressSlider = (w?.whoopStressLevel ?? 2.2).clamp(0.0, 3.0);

    _hrvCtrl = TextEditingController(
      text: (w?.hrvMs ?? 54.0).toStringAsFixed(0),
    );
    _rhrCtrl = TextEditingController(
      text: (w?.restingHr ?? 58).toString(),
    );
    _sleepHoursCtrl = TextEditingController(
      text: (w?.sleepHours ?? 6.8).toStringAsFixed(1),
    );

    _huaweiStressCtrl = TextEditingController(
      text: (w?.huaweiStressScore ?? 45).toString(),
    );
    _huaweiTruSleepCtrl = TextEditingController(
      text: (w?.huaweiTruSleepScore ?? 82).toString(),
    );
    _huaweiAvgHrCtrl = TextEditingController(
      text: (w?.avgHr ?? 68).toString(),
    );
    _huaweiVo2MaxCtrl = TextEditingController(
      text: (w?.huaweiVo2Max ?? 52.0).toStringAsFixed(1),
    );

    _samsungEnergyCtrl = TextEditingController(
      text: (w?.samsungEnergyScore ?? 78).toString(),
    );
    _samsungMusclePctCtrl = TextEditingController(
      text: (w?.samsungBiaMusclePct ?? 43.8).toStringAsFixed(1),
    );
    _samsungFatPctCtrl = TextEditingController(
      text: (w?.samsungBiaFatPct ?? 13.8).toStringAsFixed(1),
    );

    _appleMoveKcalCtrl = TextEditingController(
      text: (w?.appleMoveKcal ?? 720).toString(),
    );
    _appleExerciseMinCtrl = TextEditingController(
      text: (w?.appleExerciseMinutes ?? 52).toString(),
    );
    _appleStandHoursCtrl = TextEditingController(
      text: (w?.appleStandHours ?? 12).toString(),
    );
  }

  @override
  void dispose() {
    _hrvCtrl.dispose();
    _rhrCtrl.dispose();
    _sleepHoursCtrl.dispose();
    _huaweiStressCtrl.dispose();
    _huaweiTruSleepCtrl.dispose();
    _huaweiAvgHrCtrl.dispose();
    _huaweiVo2MaxCtrl.dispose();
    _samsungEnergyCtrl.dispose();
    _samsungMusclePctCtrl.dispose();
    _samsungFatPctCtrl.dispose();
    _appleMoveKcalCtrl.dispose();
    _appleExerciseMinCtrl.dispose();
    _appleStandHoursCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final int rhr = (int.tryParse(_rhrCtrl.text.trim()) ?? 58).clamp(30, 130);
    final double hrv =
        (double.tryParse(_hrvCtrl.text.trim()) ?? 54.0).clamp(10.0, 250.0);
    final double sleepH =
        (double.tryParse(_sleepHoursCtrl.text.trim()) ?? 6.8).clamp(0.0, 24.0);

    double computedRecovery = _recoverySlider;
    double computedStrain = _strainSlider;
    double computedSleepPct = _whoopSleepPctSlider;

    final int huaweiStress =
        (int.tryParse(_huaweiStressCtrl.text.trim()) ?? 45).clamp(1, 100);
    final int huaweiTruSleep =
        (int.tryParse(_huaweiTruSleepCtrl.text.trim()) ?? 82).clamp(1, 100);
    final int huaweiAvgHr =
        (int.tryParse(_huaweiAvgHrCtrl.text.trim()) ?? 68).clamp(35, 200);
    final double huaweiVo2 =
        (double.tryParse(_huaweiVo2MaxCtrl.text.trim()) ?? 52.0)
            .clamp(15.0, 90.0);

    final int samsungEnergy =
        (int.tryParse(_samsungEnergyCtrl.text.trim()) ?? 78).clamp(1, 100);
    final double samsungMuscle =
        (double.tryParse(_samsungMusclePctCtrl.text.trim()) ?? 43.8)
            .clamp(15.0, 75.0);
    final double samsungFat =
        (double.tryParse(_samsungFatPctCtrl.text.trim()) ?? 13.8)
            .clamp(3.0, 60.0);

    final int appleMove =
        (int.tryParse(_appleMoveKcalCtrl.text.trim()) ?? 720).clamp(0, 5000);
    final int appleEx =
        (int.tryParse(_appleExerciseMinCtrl.text.trim()) ?? 52).clamp(0, 600);
    final int appleStand =
        (int.tryParse(_appleStandHoursCtrl.text.trim()) ?? 12).clamp(0, 24);

    if (widget.activeSource == 'HUAWEI_GT') {
      computedRecovery =
          ((100 - huaweiStress) * 0.45 + huaweiTruSleep * 0.55).clamp(10.0, 99.0);
      computedSleepPct = huaweiTruSleep.toDouble();
    } else if (widget.activeSource == 'SAMSUNG_WATCH') {
      computedRecovery = samsungEnergy.toDouble();
      computedSleepPct = ((sleepH / 8.0) * 100.0).clamp(40.0, 100.0);
    } else if (widget.activeSource == 'APPLE_WATCH') {
      computedRecovery = ((hrv / 85.0) * 82.0).clamp(25.0, 98.0);
      computedStrain = ((appleMove / 1000.0) * 16.0).clamp(2.0, 20.5);
    }

    final WearableMetricRecord record = WearableMetricRecord(
      date: DateTime.now(),
      recoveryScore: double.parse(computedRecovery.toStringAsFixed(0)),
      strainScore: double.parse(computedStrain.toStringAsFixed(1)),
      hrvMs: hrv,
      restingHr: rhr,
      avgHr: widget.activeSource == 'HUAWEI_GT'
          ? huaweiAvgHr
          : (rhr + 14).clamp(45, 190),
      maxHr: 172,
      sleepHours: sleepH,
      sleepEfficiencyPct: double.parse(computedSleepPct.toStringAsFixed(0)),
      sourceDevice: widget.activeSource,
      whoopStressLevel: double.parse(_whoopStressSlider.toStringAsFixed(1)),
      whoopHealthMetricsInRange: 5,
      huaweiStressScore: huaweiStress,
      huaweiTruSleepScore: huaweiTruSleep,
      huaweiVo2Max: huaweiVo2,
      samsungEnergyScore: samsungEnergy,
      samsungBiaMusclePct: samsungMuscle,
      samsungBiaFatPct: samsungFat,
      appleMoveKcal: appleMove,
      appleExerciseMinutes: appleEx,
      appleStandHours: appleStand,
    );

    final bool ok =
        await widget.viewModel.saveDirectWearableTelemetry(record);
    if (ok && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String src = widget.activeSource;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (src == 'WHOOP') ..._buildWhoopModalFields(),
              if (src == 'HUAWEI_GT') ..._buildHuaweiModalFields(),
              if (src == 'SAMSUNG_WATCH') ..._buildSamsungModalFields(),
              if (src == 'APPLE_WATCH') ..._buildAppleWatchModalFields(),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: ApexTheme.cyanElectric,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _submit,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  src == 'WHOOP'
                      ? 'GUARDAR MÉTRICAS WHOOP EN POSTGRESQL'
                      : (src == 'HUAWEI_GT'
                          ? 'GUARDAR MÉTRICAS HUAWEI EN POSTGRESQL'
                          : (src == 'SAMSUNG_WATCH'
                              ? 'GUARDAR MÉTRICAS SAMSUNG EN POSTGRESQL'
                              : 'GUARDAR MÉTRICAS APPLE WATCH EN POSTGRESQL')),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildWhoopModalFields() {
    final Color recColor = ApexTheme.readinessColor(_recoverySlider);
    return <Widget>[
      const Text(
        'REGISTRAR MÉTRICAS WHOOP 4.0',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: ApexTheme.cyanElectric,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Ingresa Recuperación %, Strain (0-21), Sueño %, FC Reposo, HRV y Nivel de Estrés (0-3).',
        style: TextStyle(fontSize: 11.5, color: ApexTheme.textMuted),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ApexTheme.obsidianBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: recColor.withValues(alpha: 0.6)),
        ),
        child: Column(
          children: <Widget>[
            _buildSliderHeader(
              'RECUPERACIÓN (0–100%)',
              '${_recoverySlider.toStringAsFixed(0)}%',
              recColor,
            ),
            Slider(
              value: _recoverySlider,
              min: 0,
              max: 100,
              divisions: 100,
              activeColor: recColor,
              onChanged: (double v) => setState(() => _recoverySlider = v),
            ),
            _buildSliderHeader(
              'ESFUERZO / STRAIN (0–21)',
              _strainSlider.toStringAsFixed(1),
              ApexTheme.cyanElectric,
            ),
            Slider(
              value: _strainSlider,
              min: 0,
              max: 21,
              divisions: 210,
              activeColor: ApexTheme.cyanElectric,
              onChanged: (double v) => setState(() => _strainSlider = v),
            ),
            _buildSliderHeader(
              'SUEÑO % (0–100%)',
              '${_whoopSleepPctSlider.toStringAsFixed(0)}%',
              const Color(0xFF75A8D3),
            ),
            Slider(
              value: _whoopSleepPctSlider,
              min: 0,
              max: 100,
              divisions: 100,
              activeColor: const Color(0xFF75A8D3),
              onChanged: (double v) =>
                  setState(() => _whoopSleepPctSlider = v),
            ),
            _buildSliderHeader(
              'NIVEL DE ESTRÉS WHOOP (0.0–3.0)',
              '${_whoopStressSlider.toStringAsFixed(1)} (${_whoopStressSlider >= 2.0 ? "ALTO" : (_whoopStressSlider >= 1.0 ? "MEDIO" : "BAJO")})',
              ApexTheme.warningAmber,
            ),
            Slider(
              value: _whoopStressSlider,
              min: 0.0,
              max: 3.0,
              divisions: 30,
              activeColor: ApexTheme.warningAmber,
              onChanged: (double v) => setState(() => _whoopStressSlider = v),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Row(
        spacing: 8,
        children: <Widget>[
          Expanded(
            child: TextFormField(
              controller: _hrvCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'HRV (ms)',
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: _rhrCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'FC Reposo (bpm)',
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildHuaweiModalFields() {
    return <Widget>[
      const Text(
        'REGISTRAR MÉTRICAS HUAWEI GT / WATCH',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: ApexTheme.cyanElectric,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Ingresa Nivel de Estrés (0-100), Puntuación TruSleep, FC Media y VO2Max.',
        style: TextStyle(fontSize: 11.5, color: ApexTheme.textMuted),
      ),
      const SizedBox(height: 12),
      Row(
        spacing: 8,
        children: <Widget>[
          Expanded(
            child: TextFormField(
              controller: _huaweiStressCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nivel Estrés (0-100)',
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: _huaweiTruSleepCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Puntuación TruSleep',
                isDense: true,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        spacing: 8,
        children: <Widget>[
          Expanded(
            child: TextFormField(
              controller: _huaweiAvgHrCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'FC Media (bpm)',
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: _huaweiVo2MaxCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'VO2Max (ml/kg/min)',
                isDense: true,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        spacing: 8,
        children: <Widget>[
          Expanded(
            child: TextFormField(
              controller: _hrvCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'HRV (ms)',
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: _sleepHoursCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Horas de Sueño (h)',
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildSamsungModalFields() {
    return <Widget>[
      const Text(
        'REGISTRAR MÉTRICAS SAMSUNG GALAXY WATCH',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: ApexTheme.cyanElectric,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Ingresa Puntuación de Energía (Energy Score), Tiempo de Sueño y Composición Corporal BIA.',
        style: TextStyle(fontSize: 11.5, color: ApexTheme.textMuted),
      ),
      const SizedBox(height: 12),
      Row(
        spacing: 8,
        children: <Widget>[
          Expanded(
            child: TextFormField(
              controller: _samsungEnergyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Energy Score (0-100)',
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: _sleepHoursCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Tiempo de Sueño (h)',
                isDense: true,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        spacing: 8,
        children: <Widget>[
          Expanded(
            child: TextFormField(
              controller: _samsungMusclePctCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'BIA % Músculo',
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: _samsungFatPctCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'BIA % Grasa',
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildAppleWatchModalFields() {
    return <Widget>[
      const Text(
        'REGISTRAR MÉTRICAS APPLE WATCH',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: ApexTheme.cyanElectric,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Ingresa los 3 Anillos (Moverse kcal, Ejercicio min, De Pie h) y Variabilidad HRV.',
        style: TextStyle(fontSize: 11.5, color: ApexTheme.textMuted),
      ),
      const SizedBox(height: 12),
      Row(
        spacing: 8,
        children: <Widget>[
          Expanded(
            child: TextFormField(
              controller: _appleMoveKcalCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Moverse (kcal)',
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: _appleExerciseMinCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Ejercicio (min)',
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: _appleStandHoursCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'De Pie (h)',
                isDense: true,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        spacing: 8,
        children: <Widget>[
          Expanded(
            child: TextFormField(
              controller: _hrvCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Variabilidad HRV (ms)',
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: _rhrCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'FC Reposo (bpm)',
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildSliderHeader(String title, String val, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: ApexTheme.textMuted,
          ),
        ),
        Text(
          val,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final IconData icon;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: accent, size: 17),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: ApexTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: ApexTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BioStatItem extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _BioStatItem({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
              color: ApexTheme.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: highlight ? ApexTheme.voltAccent : ApexTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
