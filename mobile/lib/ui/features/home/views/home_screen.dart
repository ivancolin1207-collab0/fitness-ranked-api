import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../data/models/auth_models.dart';
import '../../../../data/models/biometric_models.dart';
import '../../../core/app_theme.dart';
import '../../auth/view_models/auth_view_model.dart';
import '../../auth/views/profile_setup_screen.dart';
import '../view_models/home_view_model.dart';
import 'dual_readiness_ring_painter.dart';

class HomeScreen extends StatelessWidget {
  final HomeViewModel viewModel;
  final AuthViewModel authViewModel;

  const HomeScreen({
    super.key,
    required this.viewModel,
    required this.authViewModel,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[viewModel, authViewModel]),
      builder: (BuildContext context, _) {
        final UserProfileModel? user = authViewModel.currentUser;
        final WearableMetricRecord? wearable = viewModel.wearable;
        final BiometricRecord? bio = viewModel.biometrics;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'BIOMETRÍA & READINESS',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                if (user != null)
                  Text(
                    '@${user.username} • ${user.fullName ?? "Atleta"} • ${user.trainingGoal}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: ApexTheme.cyanElectric,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            actions: <Widget>[
              ActionChip(
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
              IconButton(
                tooltip: 'Editar Perfil',
                icon: const Icon(Icons.manage_accounts_outlined),
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
                tooltip: 'Cerrar sesión',
                icon: const Icon(
                  Icons.logout_rounded,
                  color: ApexTheme.textMuted,
                ),
                onPressed: authViewModel.logout,
              ),
            ],
          ),
          body: viewModel.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: viewModel.initializeDashboard,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
                        children: <Widget>[
                          if (viewModel.errorMessage != null)
                            _buildAlertBanner(
                              viewModel.errorMessage!,
                              ApexTheme.deloadCrimson,
                            ),
                          if (viewModel.statusBanner != null)
                            _buildAlertBanner(
                              viewModel.statusBanner!,
                              ApexTheme.readinessGreen,
                            ),
                          _buildWearableSourceBar(context),
                          const SizedBox(height: 12),
                          if (wearable == null)
                            _buildWaitingWearableSyncCard(context)
                          else ...<Widget>[
                            _buildDualRingHeroCard(context, wearable),
                            const SizedBox(height: 14),
                            _buildWearableTelemetryRow(wearable),
                          ],
                          const SizedBox(height: 16),
                          _buildDualBiometricCaptureActions(context),
                          const SizedBox(height: 14),
                          if (bio != null)
                            _buildBodyCompositionCard(context, bio)
                          else
                            _buildEmptyBiometricsCard(context),
                          const SizedBox(height: 14),
                          _buildLbmTrendChartCard(),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildAlertBanner(String text, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildWearableSourceBar(BuildContext context) {
    final String selected = viewModel.preferredWearable;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.watch_rounded,
              color: ApexTheme.cyanElectric,
              size: 18,
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
                value: selected,
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
                    value: 'HEALTH_CONNECT',
                    child: Text('HEALTH CONNECT'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'HUAWEI_GT',
                    child: Text('HUAWEI GT'),
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

  Widget _buildWaitingWearableSyncCard(BuildContext context) {
    final String sourceName = viewModel.preferredWearable == 'WHOOP'
        ? 'Whoop'
        : viewModel.preferredWearable;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: ApexTheme.cyanElectric, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            const Icon(
              Icons.sync_problem_rounded,
              color: ApexTheme.cyanElectric,
              size: 42,
            ),
            const SizedBox(height: 10),
            Text(
              'Esperando sincronización de $sourceName',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: ApexTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Aún no se han recibido métricas reales de Recovery, Strain, HRV, FC en reposo y Sueño para el día de hoy.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: ApexTheme.textMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: <Widget>[
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: ApexTheme.voltAccent,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: viewModel.isSyncingWearable
                      ? null
                      : viewModel.forceSyncWearable,
                  icon: viewModel.isSyncingWearable
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: const Text(
                    'FORZAR SYNC',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ApexTheme.cyanElectric,
                    side: const BorderSide(color: ApexTheme.cyanElectric),
                  ),
                  onPressed: () => _openWearableManualSyncModal(context),
                  icon: const Icon(Icons.edit_attributes_outlined),
                  label: Text(
                    'REGISTRAR $sourceName HOY',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDualRingHeroCard(
    BuildContext context,
    WearableMetricRecord wearable,
  ) {
    final double recovery = wearable.recoveryScore;
    final double strain = wearable.strainScore;
    final Color recColor = ApexTheme.readinessColor(recovery);
    final String zoneLabel = recovery < 40.0
        ? 'ZONA ROJA • DESCARGA (-15% CARGA)'
        : (recovery > 80.0
            ? 'ZONA VERDE • SOBRECARGA (+2.5 KG)'
            : 'ZONA AMARILLA • MANTENIMIENTO');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                SizedBox(
                  width: 146,
                  height: 146,
                  child: CustomPaint(
                    painter: DualReadinessRingPainter(
                      recoveryScore: recovery,
                      strainScore: strain,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '${recovery.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: recColor,
                            ),
                          ),
                          const Text(
                            'RECOVERY',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.1,
                              color: ApexTheme.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'STRAIN ${strain.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: ApexTheme.cyanElectric,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: recColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          zoneLabel,
                          style: TextStyle(
                            color: recColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Fuente activa: ${wearable.sourceDevice}',
                        style: const TextStyle(
                          color: ApexTheme.cyanElectric,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Gemini Coach ajusta tus series en vivo según tu HRV, sueño y recuperación real.',
                        style: TextStyle(
                          color: ApexTheme.textPrimary,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: <Widget>[
                           OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: ApexTheme.voltAccent,
                              side: const BorderSide(
                                color: ApexTheme.voltAccent,
                              ),
                            ),
                            onPressed: viewModel.isSyncingWearable
                                ? null
                                : viewModel.forceSyncWearable,
                            icon: const Icon(Icons.sync_rounded, size: 15),
                            label: const Text(
                              'Forzar Sync',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () =>
                                _openWearableManualSyncModal(context),
                            child: const Text(
                              'Actualizar datos',
                              style: TextStyle(
                                fontSize: 11,
                                color: ApexTheme.cyanElectric,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWearableTelemetryRow(WearableMetricRecord wearable) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _MetricTile(
            label: 'HRV (RMSSD)',
            value: '${wearable.hrvMs.toStringAsFixed(0)} ms',
            accent: ApexTheme.voltAccent,
            icon: Icons.monitor_heart_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
            label: 'FC REPOSO',
            value: '${wearable.restingHr} bpm',
            accent: ApexTheme.cyanElectric,
            icon: Icons.favorite_border_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
            label: 'SUEÑO',
            value: '${wearable.sleepHours.toStringAsFixed(1)} h',
            accent: ApexTheme.readinessGreen,
            icon: Icons.bedtime_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildDualBiometricCaptureActions(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: ApexTheme.cardGraphite,
              foregroundColor: ApexTheme.voltAccent,
              side: const BorderSide(color: ApexTheme.voltAccent),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => _openBiometricFormModal(context, null),
            icon: const Icon(Icons.edit_note_rounded, size: 20),
            label: const Text(
              'CAPTURA MANUAL',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: ApexTheme.voltAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: viewModel.isScanningOcr
                ? null
                : () => _showOcrSourcePicker(context),
            icon: viewModel.isScanningOcr
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(Icons.document_scanner_rounded, size: 18),
            label: Text(
              viewModel.isScanningOcr
                  ? 'ESCANEANDO...'
                  : 'ESCANEAR FITDAYS',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyBiometricsCard(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.monitor_weight_outlined,
              color: ApexTheme.voltAccent,
              size: 38,
            ),
            SizedBox(height: 8),
            Text(
              'SIN REGISTROS DE COMPOSICIÓN CORPORAL',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              'Usa "Captura Manual" o "Escanear Fitdays" para registrar tu peso, % grasa, masa muscular, grasa visceral, agua corporal y BMR en PostgreSQL.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: ApexTheme.textMuted),
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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'COMPOSICIÓN CORPORAL (${bio.sourceProvider})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
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
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 14,
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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'HISTORIAL REAL DE MASA MAGRA (LBM KG • POSTGRESQL)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: ApexTheme.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            if (spots.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'Registra tu primera captura biométrica para graficar tu tendencia real.',
                    style: TextStyle(color: ApexTheme.textMuted, fontSize: 12),
                  ),
                ),
              )
            else
              SizedBox(
                height: 140,
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
                  'Gemini Vision extraerá los datos y abrirá el formulario para que los revises antes de guardar.',
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

  void _openWearableManualSyncModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ApexTheme.cardGraphite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return _WearableDirectSyncModalSheet(viewModel: viewModel);
      },
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
          : (latest != null ? latest.weightKg.toStringAsFixed(1) : ''),
    );
    _fatPctCtrl = TextEditingController(
      text: p != null
          ? p.fatPercentage.toStringAsFixed(1)
          : (latest != null ? latest.fatPercentage.toStringAsFixed(1) : ''),
    );
    _muscleKgCtrl = TextEditingController(
      text: p != null
          ? p.muscleMassKg.toStringAsFixed(1)
          : (latest != null ? latest.muscleMassKg.toStringAsFixed(1) : ''),
    );
    _skeletalPctCtrl = TextEditingController(
      text: p != null
          ? p.skeletalMusclePct.toStringAsFixed(1)
          : (latest != null ? latest.skeletalMusclePct.toStringAsFixed(1) : ''),
    );
    _visceralCtrl = TextEditingController(
      text: p != null
          ? p.visceralFat.toString()
          : (latest != null ? latest.visceralFat.toString() : ''),
    );
    _waterPctCtrl = TextEditingController(
      text: p != null
          ? p.bodyWaterPct.toStringAsFixed(1)
          : (latest != null ? latest.bodyWaterPct.toStringAsFixed(1) : ''),
    );
    _bmrCtrl = TextEditingController(
      text: p != null
          ? p.bmr.toString()
          : (latest != null ? latest.bmr.toString() : ''),
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
        top: 20,
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
              const SizedBox(height: 16),
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              _buildNumberField(
                controller: _bmrCtrl,
                label: 'BMR / Metabolismo Basal (kcal)',
                min: 800,
                max: 5500,
                isInteger: true,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: ApexTheme.voltAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
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

class _WearableDirectSyncModalSheet extends StatefulWidget {
  final HomeViewModel viewModel;

  const _WearableDirectSyncModalSheet({
    required this.viewModel,
  });

  @override
  State<_WearableDirectSyncModalSheet> createState() =>
      _WearableDirectSyncModalSheetState();
}

class _WearableDirectSyncModalSheetState
    extends State<_WearableDirectSyncModalSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _recoveryCtrl;
  late final TextEditingController _strainCtrl;
  late final TextEditingController _hrvCtrl;
  late final TextEditingController _rhrCtrl;
  late final TextEditingController _sleepCtrl;

  @override
  void initState() {
    super.initState();
    final WearableMetricRecord? w = widget.viewModel.wearable;
    _recoveryCtrl = TextEditingController(
      text: w != null ? w.recoveryScore.toStringAsFixed(0) : '',
    );
    _strainCtrl = TextEditingController(
      text: w != null ? w.strainScore.toStringAsFixed(1) : '',
    );
    _hrvCtrl = TextEditingController(
      text: w != null ? w.hrvMs.toStringAsFixed(0) : '',
    );
    _rhrCtrl = TextEditingController(
      text: w != null ? w.restingHr.toString() : '',
    );
    _sleepCtrl = TextEditingController(
      text: w != null ? w.sleepHours.toStringAsFixed(1) : '',
    );
  }

  @override
  void dispose() {
    _recoveryCtrl.dispose();
    _strainCtrl.dispose();
    _hrvCtrl.dispose();
    _rhrCtrl.dispose();
    _sleepCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final int rhr = int.parse(_rhrCtrl.text.trim());
    final WearableMetricRecord record = WearableMetricRecord(
      date: DateTime.now(),
      recoveryScore: double.parse(_recoveryCtrl.text.trim()),
      strainScore: double.parse(_strainCtrl.text.trim()),
      hrvMs: double.parse(_hrvCtrl.text.trim()),
      restingHr: rhr,
      avgHr: (rhr + 14).clamp(45, 190),
      maxHr: 168,
      sleepHours: double.parse(_sleepCtrl.text.trim()),
      sleepEfficiencyPct: 90.0,
      sourceDevice: widget.viewModel.preferredWearable,
    );

    final bool ok =
        await widget.viewModel.saveDirectWearableTelemetry(record);
    if (ok && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String source = widget.viewModel.preferredWearable;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
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
                'SINCRONIZAR TELEMETRÍA $source DE HOY',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: ApexTheme.cyanElectric,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _recoveryCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Recovery (0-100%)',
                      ),
                      validator: (String? v) {
                        final double? d = double.tryParse((v ?? '').trim());
                        if (d == null || d < 0 || d > 100) return '0 - 100%';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _strainCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Strain (0-21)',
                      ),
                      validator: (String? v) {
                        final double? d = double.tryParse((v ?? '').trim());
                        if (d == null || d < 0 || d > 21) return '0 - 21';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _hrvCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'HRV RMSSD (ms)',
                      ),
                      validator: (String? v) {
                        final double? d = double.tryParse((v ?? '').trim());
                        if (d == null || d < 10 || d > 250) return '10 - 250 ms';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _rhrCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'FC Reposo (bpm)',
                      ),
                      validator: (String? v) {
                        final int? d = int.tryParse((v ?? '').trim());
                        if (d == null || d < 30 || d > 130) return '30 - 130';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sleepCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Horas de Sueño (h)',
                ),
                validator: (String? v) {
                  final double? d = double.tryParse((v ?? '').trim());
                  if (d == null || d < 0 || d > 24) return '0 - 24 h';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: ApexTheme.cyanElectric,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _submit,
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  'SINCRONIZAR $source CON POSTGRESQL',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: accent, size: 18),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: ApexTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
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
      width: 145,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: ApexTheme.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: highlight ? ApexTheme.voltAccent : ApexTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
