import 'dart:math' as math;
import 'package:health/health.dart';
import '../../data/models/biometric_models.dart';

class HealthConnectPollResult {
  final WearableMetricRecord? record;
  final bool sdkAvailable;
  final bool permissionGranted;
  final String statusMessage;

  const HealthConnectPollResult({
    this.record,
    required this.sdkAvailable,
    required this.permissionGranted,
    required this.statusMessage,
  });
}

class HealthConnectService {
  final Health _health = Health();

  static const List<HealthDataType> _types = <HealthDataType>[
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
  ];

  static final List<HealthDataAccess> _permissions = List<HealthDataAccess>.filled(
    _types.length,
    HealthDataAccess.READ,
  );

  /// Solicita explícitamente permisos de lectura en tiempo de ejecución a Android Health Connect
  /// y agrega las métricas de las últimas 24 horas (Whoop, Samsung Health, Huawei GT, Health Connect).
  Future<HealthConnectPollResult> requestPermissionsAndPollToday({
    String preferredSource = 'WHOOP',
  }) async {
    try {
      await _health.configure();

      final HealthConnectSdkStatus? sdkStatus =
          await _health.getHealthConnectSdkStatus();
      if (sdkStatus != null &&
          sdkStatus != HealthConnectSdkStatus.sdkAvailable) {
        return const HealthConnectPollResult(
          sdkAvailable: false,
          permissionGranted: false,
          statusMessage: 'Sin telemetría sincronizada en Health Connect hoy',
        );
      }

      final bool granted = await _health.requestAuthorization(
        _types,
        permissions: _permissions,
      );
      if (!granted) {
        return const HealthConnectPollResult(
          sdkAvailable: true,
          permissionGranted: false,
          statusMessage: 'Sin telemetría sincronizada en Health Connect hoy',
        );
      }

      final DateTime now = DateTime.now();
      final DateTime yesterday = now.subtract(const Duration(hours: 24));
      final List<HealthDataPoint> points =
          await _health.getHealthDataFromTypes(
        types: _types,
        startTime: yesterday,
        endTime: now,
      );

      final int? totalSteps =
          await _health.getTotalStepsInInterval(yesterday, now);

      if (points.isEmpty && (totalSteps == null || totalSteps <= 0)) {
        return const HealthConnectPollResult(
          sdkAvailable: true,
          permissionGranted: true,
          statusMessage: 'Sin telemetría sincronizada en Health Connect hoy',
        );
      }

      final WearableMetricRecord? parsed = _aggregatePoints(
        points: points,
        totalSteps: totalSteps ?? 0,
        now: now,
        preferredSource: preferredSource,
      );

      if (parsed == null) {
        return const HealthConnectPollResult(
          sdkAvailable: true,
          permissionGranted: true,
          statusMessage: 'Sin telemetría sincronizada en Health Connect hoy',
        );
      }

      return HealthConnectPollResult(
        record: parsed,
        sdkAvailable: true,
        permissionGranted: true,
        statusMessage:
            'Sincronización $preferredSource completada (Recovery: ${parsed.recoveryScore.toStringAsFixed(0)}%)',
      );
    } catch (_) {
      return const HealthConnectPollResult(
        sdkAvailable: false,
        permissionGranted: false,
        statusMessage: 'Sin telemetría sincronizada en Health Connect hoy',
      );
    }
  }

  /// Lee métricas reales de las últimas 24h desde Android Health Connect.
  Future<WearableMetricRecord?> fetchTodayWearableMetrics({
    String preferredSource = 'WHOOP',
  }) async {
    final HealthConnectPollResult res = await requestPermissionsAndPollToday(
      preferredSource: preferredSource,
    );
    return res.record;
  }

  WearableMetricRecord? _aggregatePoints({
    required List<HealthDataPoint> points,
    required int totalSteps,
    required DateTime now,
    required String preferredSource,
  }) {
    double? latestHrv;
    int? restingHr;
    final List<int> hrSamples = <int>[];
    double sleepAsleepMinutes = 0.0;
    double sleepSessionMinutes = 0.0;
    double activeKcal = 0.0;
    double totalKcal = 0.0;
    int stepPoints = 0;

    for (final HealthDataPoint p in points) {
      final HealthValue val = p.value;
      if (val is NumericHealthValue) {
        final double numVal = val.numericValue.toDouble();
        switch (p.type) {
          case HealthDataType.HEART_RATE_VARIABILITY_RMSSD:
            latestHrv = numVal.clamp(10.0, 250.0);
          case HealthDataType.RESTING_HEART_RATE:
            restingHr = numVal.round().clamp(30, 120);
          case HealthDataType.HEART_RATE:
            hrSamples.add(numVal.round().clamp(35, 220));
          case HealthDataType.SLEEP_ASLEEP:
            sleepAsleepMinutes += numVal;
          case HealthDataType.SLEEP_SESSION:
            sleepSessionMinutes += numVal;
          case HealthDataType.ACTIVE_ENERGY_BURNED:
            activeKcal += numVal;
          case HealthDataType.TOTAL_CALORIES_BURNED:
            totalKcal += numVal;
          case HealthDataType.STEPS:
            stepPoints += numVal.round();
          default:
            break;
        }
      }
    }

    final double resolvedSleepMinutes = sleepAsleepMinutes > 0
        ? sleepAsleepMinutes
        : sleepSessionMinutes;
    final int resolvedSteps = math.max(totalSteps, stepPoints);

    if (latestHrv == null &&
        restingHr == null &&
        hrSamples.isEmpty &&
        resolvedSleepMinutes <= 0 &&
        activeKcal <= 0 &&
        totalKcal <= 0 &&
        resolvedSteps <= 0) {
      return null;
    }

    final int avgHr = hrSamples.isNotEmpty
        ? (hrSamples.reduce((int a, int b) => a + b) / hrSamples.length).round()
        : (restingHr ?? 62);
    final int maxHr = hrSamples.isNotEmpty
        ? hrSamples.reduce(math.max)
        : math.max(avgHr + 25, 110);
    final double resolvedHrv = latestHrv ?? 64.0;
    final int resolvedRhr = restingHr ?? avgHr;
    final double sleepHours = resolvedSleepMinutes > 0
        ? double.parse(
            (resolvedSleepMinutes / 60.0).clamp(0.5, 16.0).toStringAsFixed(2),
          )
        : 7.0;

    final double hrvScore =
        ((resolvedHrv - 25.0) / 75.0).clamp(0.0, 1.0) * 50.0;
    final double rhrScore =
        ((85.0 - resolvedRhr) / 40.0).clamp(0.0, 1.0) * 25.0;
    final double sleepScore = (sleepHours / 8.0).clamp(0.0, 1.0) * 25.0;
    final double recoveryScore = double.parse(
      (hrvScore + rhrScore + sleepScore).clamp(5.0, 99.0).toStringAsFixed(1),
    );

    final double effectiveActiveKcal = activeKcal > 0
        ? activeKcal
        : (totalKcal > 1400
            ? (totalKcal - 1400.0)
            : (resolvedSteps * 0.04));
    final double rawStrain =
        4.5 * math.log(1.0 + (math.max(effectiveActiveKcal, 50.0) / 180.0));
    final double strainScore = double.parse(
      rawStrain.clamp(2.0, 20.8).toStringAsFixed(1),
    );

    return WearableMetricRecord(
      date: now,
      strainScore: strainScore,
      recoveryScore: recoveryScore,
      hrvMs: resolvedHrv,
      restingHr: resolvedRhr,
      avgHr: avgHr,
      maxHr: math.max(maxHr, avgHr),
      sleepHours: sleepHours,
      sleepEfficiencyPct: 90.0,
      sourceDevice: preferredSource,
    );
  }
}
