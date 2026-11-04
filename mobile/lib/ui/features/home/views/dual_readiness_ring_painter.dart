import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';

class DualReadinessRingPainter extends CustomPainter {
  final double recoveryScore; // 0 - 100
  final double strainScore; // 0 - 21

  const DualReadinessRingPainter({
    required this.recoveryScore,
    required this.strainScore,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double outerRadius = (math.min(size.width, size.height) / 2) - 10;
    final double innerRadius = outerRadius - 20;
    const double startAngle = -math.pi / 2;

    // Pista exterior (Recovery)
    final Paint trackPaint = Paint()
      ..color = const Color(0xFF1E2636)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, outerRadius, trackPaint);
    canvas.drawCircle(center, innerRadius, trackPaint..strokeWidth = 10);

    // Arco exterior: Recovery Score semaforizado (<40% Rojo, 40-80% Amarillo, >80% Verde)
    final Color recoveryColor = ApexTheme.readinessColor(recoveryScore);
    final double recoverySweep =
        2 * math.pi * (recoveryScore.clamp(0.0, 100.0) / 100.0);

    final Paint recoveryPaint = Paint()
      ..color = recoveryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerRadius),
      startAngle,
      recoverySweep,
      false,
      recoveryPaint,
    );

    // Arco interior: Strain diario (escala Whoop/Huawei 0.0 - 21.0)
    final double strainSweep =
        2 * math.pi * (strainScore.clamp(0.0, 21.0) / 21.0);
    final Paint strainPaint = Paint()
      ..color = ApexTheme.cyanElectric
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: innerRadius),
      startAngle,
      strainSweep,
      false,
      strainPaint,
    );
  }

  @override
  bool shouldRepaint(covariant DualReadinessRingPainter oldDelegate) {
    return oldDelegate.recoveryScore != recoveryScore ||
        oldDelegate.strainScore != strainScore;
  }
}
