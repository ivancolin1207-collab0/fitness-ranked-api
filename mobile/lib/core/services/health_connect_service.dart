import 'dart:math' as math;
import 'package:flutter/services.dart';
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

class _TimeInterval {
  DateTime start;
  DateTime end;
  _TimeInterval(this.start, this.end);
}

class HealthConnectService {
  final Health _health = Health();
  static const MethodChannel _systemChannel =
      MethodChannel('apexmetrix/system');

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

  static final List<HealthDataAccess> _permissions =
      List<HealthDataAccess>.filled(
    _types.length,
    HealthDataAccess.READ,
  );

  /// Abre directamente la pantalla nativa de permisos de Health Connect en Android 14/15/16
  /// cuando el usuario necesita habilitar manualmente algún permiso denegado previamente.
  Future<void> openHealthConnectPermissionsSettings() async {
    try {
      await _systemChannel.invokeMethod<dynamic>('openHealthConnectSettings');
    } catch (_) {}
  }

  /// Solicita permisos de lectura en tiempo de ejecución a Android Health Connect
  /// y agrega las métricas reales de las últimas 24 horas (Whoop, Huawei Health, Samsung Health).
  Future<HealthConnectPollResult> requestPermissionsAndPollToday({
    String preferredSource = 'WHOOP',
    bool openSettingsIfDenied = false,
    int athleteAge = 28,
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
          statusMessage:
              'Health Connect no está disponible o requiere actualización en este dispositivo Android.',
        );
      }

      bool? alreadyGranted;
      try {
        alreadyGranted = await _health.hasPermissions(
          _types,
          permissions: _permissions,
        );
      } catch (_) {
        alreadyGranted = null;
      }

      bool granted = alreadyGranted == true;
      if (!granted) {
        try {
          granted = await _health.requestAuthorization(
            _types,
            permissions: _permissions,
          );
        } catch (_) {
          granted = false;
        }
      }

      // En Android 14+, `hasPermissions` o `requestAuthorization` puede devolver `false` si
      // solo se concedió un subconjunto (ej. Sueño y FC pero no Calorías). Intentamos leer
      // los tipos individualmente antes de declarar permisos denegados.
      final DateTime now = DateTime.now();
      final DateTime windowStart = now.subtract(const Duration(hours: 24));
      final List<HealthDataPoint> points = <HealthDataPoint>[];

      try {
        final List<HealthDataPoint> batch =
            await _health.getHealthDataFromTypes(
          types: _types,
          startTime: windowStart,
          endTime: now,
        );
        points.addAll(batch);
      } catch (_) {
        for (final HealthDataType singleType in _types) {
          try {
            final List<HealthDataPoint> partial =
                await _health.getHealthDataFromTypes(
              types: <HealthDataType>[singleType],
              startTime: windowStart,
              endTime: now,
            );
            points.addAll(partial);
          } catch (_) {}
        }
      }

      int totalSteps = 0;
      try {
        totalSteps =
            (await _health.getTotalStepsInInterval(windowStart, now)) ?? 0;
      } catch (_) {
        totalSteps = 0;
      }

      if (!granted && points.isEmpty && totalSteps <= 0) {
        if (openSettingsIfDenied) {
          await openHealthConnectPermissionsSettings();
        }
        return const HealthConnectPollResult(
          sdkAvailable: true,
          permissionGranted: false,
          statusMessage:
              'Concede permisos de lectura a ApexMetrix en Android Health Connect (Sueño, FC, HRV y Calorías).',
        );
      }

      if (points.isEmpty && totalSteps <= 0) {
        return const HealthConnectPollResult(
          sdkAvailable: true,
          permissionGranted: true,
          statusMessage:
              'Health Connect conectado, pero Whoop / Huawei / Samsung aún no han escrito registros en las últimas 24h.',
        );
      }

      final WearableMetricRecord? parsed = _aggregatePoints(
        points: List<HealthDataPoint>.from(_health.removeDuplicates(points)),
        totalSteps: totalSteps,
        now: now,
        preferredSource: preferredSource,
        athleteAge: athleteAge,
      );

      if (parsed == null) {
        return const HealthConnectPollResult(
          sdkAvailable: true,
          permissionGranted: true,
          statusMessage:
              'Sin métricas fisiológicas de sueño, FC o HRV en Health Connect en las últimas 24h.',
        );
      }

      return HealthConnectPollResult(
        record: parsed,
        sdkAvailable: true,
        permissionGranted: true,
        statusMessage:
            'Health Connect sincronizado (${parsed.sourceDevice}): Recuperación ${parsed.recoveryScore.toStringAsFixed(0)}% • Strain ${parsed.strainScore.toStringAsFixed(1)}',
      );
    } catch (err) {
      return HealthConnectPollResult(
        sdkAvailable: false,
        permissionGranted: false,
        statusMessage: 'Error al consultar Health Connect: $err',
      );
    }
  }

  /// Lee métricas reales de las últimas 24h desde Android Health Connect.
  Future<WearableMetricRecord?> fetchTodayWearableMetrics({
    String preferredSource = 'WHOOP',
    int athleteAge = 28,
  }) async {
    final HealthConnectPollResult res = await requestPermissionsAndPollToday(
      preferredSource: preferredSource,
      athleteAge: athleteAge,
    );
    return res.record;
  }

  double _mergeIntervalsMinutes(List<_TimeInterval> intervals) {
    if (intervals.isEmpty) {
      return 0.0;
    }
    intervals.sort(
      (_TimeInterval a, _TimeInterval b) => a.start.compareTo(b.start),
    );
    final List<_TimeInterval> merged = <_TimeInterval>[intervals.first];
    for (int i = 1; i < intervals.length; i++) {
      final _TimeInterval current = intervals[i];
      final _TimeInterval last = merged.last;
      if (!current.start.isAfter(last.end)) {
        if (current.end.isAfter(last.end)) {
          last.end = current.end;
        }
      } else {
        merged.add(current);
      }
    }
    double minutes = 0.0;
    for (final _TimeInterval item in merged) {
      final int diff = item.end.difference(item.start).inMinutes;
      if (diff > 0) {
        minutes += diff.toDouble();
      }
    }
    return minutes;
  }

  WearableMetricRecord? _aggregatePoints({
    required List<HealthDataPoint> points,
    required int totalSteps,
    required DateTime now,
    required String preferredSource,
    required int athleteAge,
  }) {
    double? latestHrv;
    DateTime? latestHrvTime;
    int? explicitRestingHr;
    DateTime? latestRhrTime;

    final List<HealthDataPoint> hrPoints = <HealthDataPoint>[];
    final List<int> hrSamples = <int>[];
    final List<_TimeInterval> sleepAsleepIntervals = <_TimeInterval>[];
    final List<_TimeInterval> sleepSessionIntervals = <_TimeInterval>[];
    double sleepAsleepNumericMin = 0.0;
    double sleepSessionNumericMin = 0.0;
    double activeKcal = 0.0;
    double totalKcal = 0.0;
    int stepPoints = 0;
    String? detectedSourcePackage;

    for (final HealthDataPoint p in points) {
      final String srcPkg = p.sourceName.toLowerCase();
      if (srcPkg.contains('whoop')) {
        detectedSourcePackage = 'WHOOP';
      } else if (srcPkg.contains('huawei')) {
        detectedSourcePackage ??= 'HUAWEI_GT';
      } else if (srcPkg.contains('shealth') || srcPkg.contains('samsung')) {
        detectedSourcePackage ??= 'SAMSUNG_WATCH';
      }

      final int spanMinutes = p.dateTo.difference(p.dateFrom).inMinutes;
      final HealthValue val = p.value;
      final double? numVal =
          val is NumericHealthValue ? val.numericValue.toDouble() : null;

      switch (p.type) {
        case HealthDataType.HEART_RATE_VARIABILITY_RMSSD:
          if (numVal != null && numVal >= 5.0 && numVal <= 300.0) {
            if (latestHrvTime == null || p.dateTo.isAfter(latestHrvTime)) {
              latestHrv = double.parse(numVal.toStringAsFixed(1));
              latestHrvTime = p.dateTo;
            }
          }
        case HealthDataType.RESTING_HEART_RATE:
          if (numVal != null && numVal >= 25.0 && numVal <= 140.0) {
            if (latestRhrTime == null || p.dateTo.isAfter(latestRhrTime)) {
              explicitRestingHr = numVal.round();
              latestRhrTime = p.dateTo;
            }
          }
        case HealthDataType.HEART_RATE:
          if (numVal != null && numVal >= 30.0 && numVal <= 230.0) {
            hrSamples.add(numVal.round());
            hrPoints.add(p);
          }
        case HealthDataType.SLEEP_ASLEEP:
          if (spanMinutes > 0 && spanMinutes <= 16 * 60) {
            sleepAsleepIntervals.add(_TimeInterval(p.dateFrom, p.dateTo));
          } else if (numVal != null && numVal > 0 && numVal <= 16 * 60) {
            sleepAsleepNumericMin += numVal;
          }
        case HealthDataType.SLEEP_SESSION:
          if (spanMinutes > 0 && spanMinutes <= 18 * 60) {
            sleepSessionIntervals.add(_TimeInterval(p.dateFrom, p.dateTo));
          } else if (numVal != null && numVal > 0 && numVal <= 18 * 60) {
            sleepSessionNumericMin += numVal;
          }
        case HealthDataType.ACTIVE_ENERGY_BURNED:
          if (numVal != null && numVal > 0) {
            activeKcal += numVal;
          }
        case HealthDataType.TOTAL_CALORIES_BURNED:
          if (numVal != null && numVal > 0) {
            totalKcal += numVal;
          }
        case HealthDataType.STEPS:
          if (numVal != null && numVal > 0) {
            stepPoints += numVal.round();
          }
        default:
          break;
      }
    }

    final double mergedAsleepMin = _mergeIntervalsMinutes(sleepAsleepIntervals);
    final double mergedSessionMin =
        _mergeIntervalsMinutes(sleepSessionIntervals);
    final double resolvedSleepMinutes = mergedAsleepMin > 0
        ? mergedAsleepMin
        : (sleepAsleepNumericMin > 0
            ? sleepAsleepNumericMin
            : (mergedSessionMin > 0
                ? mergedSessionMin
                : sleepSessionNumericMin));

    // Derivar FC en reposo desde el percentil 10 inferior de muestras reales de FC
    // cuando el wearable (Huawei / Galaxy Watch) exporta FC continua pero no RESTING_HEART_RATE aislado.
    int? derivedRestingHr = explicitRestingHr;
    if (derivedRestingHr == null && hrSamples.isNotEmpty) {
      final List<int> sortedHr = List<int>.from(hrSamples)..sort();
      final int p10Index =
          ((sortedHr.length - 1) * 0.10).floor().clamp(0, sortedHr.length - 1);
      derivedRestingHr = sortedHr[p10Index].clamp(32, 120);
    }

    // Exigir al menos una señal fisiológica real (HRV, FC/RHR, Sueño o Calorías activas)
    if (latestHrv == null &&
        derivedRestingHr == null &&
        resolvedSleepMinutes <= 0 &&
        hrSamples.isEmpty &&
        activeKcal <= 0) {
      return null;
    }

    final int avgHr = hrSamples.isNotEmpty
        ? (hrSamples.reduce((int a, int b) => a + b) / hrSamples.length).round()
        : (derivedRestingHr ?? 0);
    final int maxHr = hrSamples.isNotEmpty
        ? hrSamples.reduce(math.max)
        : (avgHr > 0 ? math.max(avgHr + 15, avgHr) : 0);

    final double resolvedHrv = latestHrv ?? 0.0;
    final int resolvedRhr = derivedRestingHr ?? 0;

    final double sleepHours = resolvedSleepMinutes > 0
        ? double.parse(
            (resolvedSleepMinutes / 60.0).clamp(0.1, 18.0).toStringAsFixed(2),
          )
        : 0.0;
    final double sleepPct = resolvedSleepMinutes > 0
        ? double.parse(
            ((resolvedSleepMinutes / 480.0) * 100.0)
                .clamp(0.0, 100.0)
                .toStringAsFixed(0),
          )
        : 0.0;

    // Cálculo de Strain (0.0 a 21.0) por carga TRIMP exponencial de Banister + calorías activas reales
    final int estimatedMaxHr =
        (208.0 - (0.7 * athleteAge.clamp(14, 85))).round().clamp(150, 210);
    final int baselineRhr = resolvedRhr > 0 ? resolvedRhr : 60;
    double trimpLoad = 0.0;

    if (hrPoints.isNotEmpty) {
      hrPoints.sort(
        (HealthDataPoint a, HealthDataPoint b) =>
            a.dateFrom.compareTo(b.dateFrom),
      );
      for (int i = 0; i < hrPoints.length; i++) {
        final HealthDataPoint pt = hrPoints[i];
        final int bpm =
            (pt.value as NumericHealthValue).numericValue.round().clamp(35, 220);
        double dtMinutes =
            pt.dateTo.difference(pt.dateFrom).inSeconds / 60.0;
        if (dtMinutes <= 0.0) {
          if (i + 1 < hrPoints.length) {
            final int gapSec =
                hrPoints[i + 1].dateFrom.difference(pt.dateFrom).inSeconds;
            dtMinutes = (gapSec > 0 && gapSec <= 300) ? (gapSec / 60.0) : 1.0;
          } else {
            dtMinutes = 1.0;
          }
        } else if (dtMinutes > 15.0) {
          dtMinutes = 5.0;
        }
        final double hrr = ((bpm - baselineRhr) /
                math.max(25, estimatedMaxHr - baselineRhr))
            .clamp(0.0, 1.0);
        if (hrr > 0.08) {
          trimpLoad += dtMinutes * hrr * 0.64 * math.exp(1.92 * hrr);
        }
      }
    }

    final int resolvedSteps = math.max(totalSteps, stepPoints);
    final double effectiveActiveKcal = activeKcal > 0
        ? activeKcal
        : (totalKcal > 1500
            ? (totalKcal - 1500.0)
            : (resolvedSteps > 0 ? resolvedSteps * 0.038 : 0.0));
    final double combinedCardioLoad =
        trimpLoad + (effectiveActiveKcal / 12.0);
    final double rawStrain = combinedCardioLoad > 0
        ? 4.65 * math.log(1.0 + (combinedCardioLoad / 18.0))
        : 0.0;
    final double strainScore = double.parse(
      rawStrain.clamp(0.0, 21.0).toStringAsFixed(1),
    );

    // Cálculo fisiológico real de Recuperación (%) ponderando únicamente las señales presentes
    double weightedSum = 0.0;
    double totalWeight = 0.0;

    if (resolvedHrv > 0) {
      final double hrvNorm =
          ((resolvedHrv - 20.0) / 85.0).clamp(0.08, 1.0) * 100.0;
      weightedSum += hrvNorm * 0.50;
      totalWeight += 0.50;
    }
    if (resolvedRhr > 0) {
      final double rhrNorm =
          ((88.0 - resolvedRhr) / 42.0).clamp(0.08, 1.0) * 100.0;
      weightedSum += rhrNorm * 0.25;
      totalWeight += 0.25;
    }
    if (sleepPct > 0) {
      weightedSum += sleepPct * 0.25;
      totalWeight += 0.25;
    }

    final double recoveryScore = totalWeight > 0
        ? double.parse(
            (weightedSum / totalWeight).clamp(1.0, 99.0).toStringAsFixed(0),
          )
        : 0.0;

    // Estimación de Estrés Cardiovascular (0.0 - 3.0) desde %HRR media real
    double stressLevel = 0.0;
    String stressCat = 'SIN DATOS';
    if (avgHr > 0 && baselineRhr > 0) {
      final double avgHrr = ((avgHr - baselineRhr) /
              math.max(25, estimatedMaxHr - baselineRhr))
          .clamp(0.0, 1.0);
      stressLevel =
          double.parse((avgHrr * 3.8).clamp(0.2, 3.0).toStringAsFixed(1));
      stressCat = stressLevel >= 2.0
          ? 'ALTO'
          : (stressLevel >= 1.0 ? 'MEDIO' : 'BAJO');
    }

    final String resolvedSource =
        preferredSource.isNotEmpty ? preferredSource : (detectedSourcePackage ?? 'WHOOP');
    final int metricsCount = (resolvedHrv > 0 ? 1 : 0) +
        (resolvedRhr > 0 ? 1 : 0) +
        (sleepPct > 0 ? 1 : 0) +
        (avgHr > 0 ? 1 : 0) +
        (strainScore > 0 ? 1 : 0);

    return WearableMetricRecord(
      date: now,
      strainScore: strainScore,
      recoveryScore: recoveryScore,
      hrvMs: resolvedHrv,
      restingHr: resolvedRhr,
      avgHr: avgHr,
      maxHr: math.max(maxHr, avgHr),
      sleepHours: sleepHours,
      sleepEfficiencyPct: sleepPct,
      sourceDevice: resolvedSource,
      whoopStressLevel: stressLevel,
      stressCategory: stressCat,
      whoopHealthMetricsInRange: metricsCount,
      huaweiTruSleepScore: sleepPct.round(),
      huaweiStressScore: (stressLevel / 3.0 * 100.0).round().clamp(0, 100),
      samsungEnergyScore: recoveryScore.round(),
    );
  }
}
