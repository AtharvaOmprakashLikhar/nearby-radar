import 'dart:math';
import 'package:flutter/material.dart';
import '../../../shared/theme/app_theme.dart';

class RadarPainter extends CustomPainter {
  final double sweepAngle; // Radians 0 .. 2*pi

  RadarPainter({required this.sweepAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) / 2 - 16;

    // 1. Dark radar background vignette
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.surfaceElevated.withOpacity(0.4),
          AppColors.background,
        ],
        stops: const [0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
    canvas.drawCircle(center, maxRadius, bgPaint);

    // 2. Concentric Distance Rings: <2m (0.33), ~5m (0.66), ~10m+ (1.0)
    final ringPaint = Paint()
      ..color = AppColors.radarGrid
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final outerRingPaint = Paint()
      ..color = AppColors.radarCyan.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Outer border
    canvas.drawCircle(center, maxRadius, outerRingPaint);
    // 10m Ring
    canvas.drawCircle(center, maxRadius * 0.72, ringPaint);
    // 5m Ring
    canvas.drawCircle(center, maxRadius * 0.44, ringPaint);
    // 2m Ring (Very Close)
    canvas.drawCircle(center, maxRadius * 0.22, ringPaint);

    // 3. Radial Crosshairs
    final crossPaint = Paint()
      ..color = AppColors.radarGrid
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(center.dx - maxRadius, center.dy), Offset(center.dx + maxRadius, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy - maxRadius), Offset(center.dx, center.dy + maxRadius), crossPaint);

    // Diagonal tick marks
    final diagPaint = Paint()
      ..color = AppColors.radarGrid.withOpacity(0.12)
      ..strokeWidth = 0.8;
    for (int i = 0; i < 4; i++) {
      final rad = (i * pi / 4) + (pi / 8);
      final dx = cos(rad) * maxRadius;
      final dy = sin(rad) * maxRadius;
      canvas.drawLine(Offset(center.dx - dx, center.dy - dy), Offset(center.dx + dx, center.dy + dy), diagPaint);
    }

    // 4. Rotating Sweep Line with Phosphor Glow Trail
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: 2 * pi,
        colors: [
          Colors.transparent,
          Colors.transparent,
          AppColors.radarCyan.withOpacity(0.02),
          AppColors.radarCyan.withOpacity(0.08),
          AppColors.radarCyan.withOpacity(0.35),
        ],
        stops: const [0.0, 0.7, 0.85, 0.95, 1.0],
        transform: GradientRotation(sweepAngle - 2 * pi),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, maxRadius, sweepPaint);

    // Leading bright line
    final linePaint = Paint()
      ..color = AppColors.radarCyan
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.0);

    final lineEndX = center.dx + cos(sweepAngle) * maxRadius;
    final lineEndY = center.dy + sin(sweepAngle) * maxRadius;
    canvas.drawLine(center, Offset(lineEndX, lineEndY), linePaint);

    // 5. Center local user beacon dot
    final centerPulse = Paint()
      ..color = AppColors.radarCyan.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 14, centerPulse);

    final centerDot = Paint()
      ..color = AppColors.radarCyan
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 5, centerDot);

    // 6. Distance labels on rings
    _drawRingLabel(canvas, center, maxRadius * 0.22, "<2m");
    _drawRingLabel(canvas, center, maxRadius * 0.44, "~5m");
    _drawRingLabel(canvas, center, maxRadius * 0.72, "~10m");
  }

  void _drawRingLabel(Canvas canvas, Offset center, double radius, String text) {
    const textStyle = TextStyle(
      color: AppColors.radarCyan,
      fontSize: 9,
      fontWeight: FontWeight.w600,
    );
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(center.dx + 4, center.dy - radius - 11),
    );
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle;
  }
}
