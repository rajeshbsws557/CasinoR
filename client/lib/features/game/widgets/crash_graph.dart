// ============================================
// Crash Graph — CustomPainter Visualization
// ============================================

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:crash_game/config/theme.dart';
import 'package:crash_game/features/game/bloc/game_bloc.dart';

class CrashGraph extends StatelessWidget {
  final List<double> multiplierHistory;
  final double currentMultiplier;
  final GamePhase phase;
  final double? cashoutMultiplier;

  const CrashGraph({
    super.key,
    required this.multiplierHistory,
    required this.currentMultiplier,
    required this.phase,
    this.cashoutMultiplier,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _CrashGraphPainter(
          points: multiplierHistory,
          currentMultiplier: currentMultiplier,
          phase: phase,
          cashoutMultiplier: cashoutMultiplier,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _CrashGraphPainter extends CustomPainter {
  final List<double> points;
  final double currentMultiplier;
  final GamePhase phase;
  final double? cashoutMultiplier;

  _CrashGraphPainter({
    required this.points,
    required this.currentMultiplier,
    required this.phase,
    this.cashoutMultiplier,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final padding = const EdgeInsets.only(left: 50, bottom: 30, top: 20, right: 20);
    final graphRect = Rect.fromLTWH(
      padding.left,
      padding.top,
      size.width - padding.left - padding.right,
      size.height - padding.top - padding.bottom,
    );

    // Draw background gradient
    _drawBackground(canvas, size);

    // Draw grid
    _drawGrid(canvas, graphRect);

    // Draw curve
    if (points.isNotEmpty) {
      _drawCurve(canvas, graphRect);
    }

    // Draw multiplier text
    _drawMultiplierText(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.5, size.height * 0.3),
        size.width * 0.8,
        [
          AppTheme.surface.withAlpha(200),
          AppTheme.background,
        ],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
  }

  void _drawGrid(Canvas canvas, Rect rect) {
    final gridPaint = Paint()
      ..color = AppTheme.border.withAlpha(60)
      ..strokeWidth = 0.5;

    final labelStyle = TextStyle(
      color: AppTheme.textMuted,
      fontSize: 10,
      fontFamily: 'JetBrains Mono',
    );

    // Determine max Y for scaling
    double maxY = math.max(currentMultiplier, 2.0);
    if (points.isNotEmpty) {
      maxY = math.max(maxY, points.reduce(math.max));
    }
    maxY = (maxY * 1.3).ceilToDouble(); // Add 30% headroom

    // Horizontal grid lines (multiplier values)
    final ySteps = _calculateGridSteps(1.0, maxY, 5);
    for (final value in ySteps) {
      final y = rect.bottom - ((value - 1.0) / (maxY - 1.0)) * rect.height;
      if (y >= rect.top && y <= rect.bottom) {
        canvas.drawLine(
          Offset(rect.left, y),
          Offset(rect.right, y),
          gridPaint,
        );

        // Label
        final tp = TextPainter(
          text: TextSpan(text: '${value.toStringAsFixed(1)}x', style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(rect.left - tp.width - 8, y - tp.height / 2));
      }
    }

    // Vertical grid lines (time)
    final xSteps = 5;
    for (int i = 0; i <= xSteps; i++) {
      final x = rect.left + (i / xSteps) * rect.width;
      canvas.drawLine(
        Offset(x, rect.top),
        Offset(x, rect.bottom),
        gridPaint,
      );
    }

    // Axes
    final axisPaint = Paint()
      ..color = AppTheme.border.withAlpha(120)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.right, rect.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left, rect.bottom),
      axisPaint,
    );
  }

  void _drawCurve(Canvas canvas, Rect rect) {
    if (points.isEmpty) return;

    double maxY = math.max(currentMultiplier, 2.0);
    maxY = math.max(maxY, points.reduce(math.max));
    maxY = (maxY * 1.3).ceilToDouble();

    final path = Path();

    // Build the curve path
    for (int i = 0; i < points.length; i++) {
      final x = rect.left + (i / math.max(points.length - 1, 1)) * rect.width;
      final normalizedY = (points[i] - 1.0) / (maxY - 1.0);
      final y = rect.bottom - normalizedY * rect.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Smooth curve using quadratic bezier
        final prevX = rect.left + ((i - 1) / math.max(points.length - 1, 1)) * rect.width;
        final prevNY = (points[i - 1] - 1.0) / (maxY - 1.0);
        final prevY = rect.bottom - prevNY * rect.height;
        final cpX = (prevX + x) / 2;
        path.quadraticBezierTo(prevX, prevY, cpX, (prevY + y) / 2);
      }
    }

    // Determine curve color based on phase and multiplier
    Color curveColor;
    if (phase == GamePhase.crashed) {
      curveColor = AppTheme.lossRed;
    } else if (currentMultiplier < 2.0) {
      curveColor = AppTheme.winGreen;
    } else if (currentMultiplier < 5.0) {
      curveColor = Color.lerp(AppTheme.winGreen, AppTheme.multiplierYellow,
          (currentMultiplier - 2.0) / 3.0)!;
    } else {
      curveColor = Color.lerp(AppTheme.multiplierYellow, AppTheme.lossRed,
          math.min(1.0, (currentMultiplier - 5.0) / 15.0))!;
    }

    // Draw the glow effect
    final glowPaint = Paint()
      ..color = curveColor.withAlpha(40)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, glowPaint);

    // Draw the main curve
    final curvePaint = Paint()
      ..color = curveColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, curvePaint);

    // Draw filled area under the curve
    final fillPath = Path.from(path);
    final lastX = rect.left + ((points.length - 1) / math.max(points.length - 1, 1)) * rect.width;
    fillPath.lineTo(lastX, rect.bottom);
    fillPath.lineTo(rect.left, rect.bottom);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(rect.left, rect.top),
        Offset(rect.left, rect.bottom),
        [
          curveColor.withAlpha(30),
          curveColor.withAlpha(5),
        ],
      );
    canvas.drawPath(fillPath, fillPaint);

    // Draw current position dot (pulsing glow)
    if (phase == GamePhase.running || phase == GamePhase.cashedOut) {
      final lastPt = Offset(
        lastX,
        rect.bottom - ((points.last - 1.0) / (maxY - 1.0)) * rect.height,
      );

      // Outer glow
      final dotGlowPaint = Paint()
        ..color = curveColor.withAlpha(60)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(lastPt, 12, dotGlowPaint);

      // Inner dot
      final dotPaint = Paint()..color = curveColor;
      canvas.drawCircle(lastPt, 5, dotPaint);

      // White center
      final dotCenter = Paint()..color = Colors.white;
      canvas.drawCircle(lastPt, 2, dotCenter);
    }

    // Draw cashout line if cashed out
    if (cashoutMultiplier != null && cashoutMultiplier! > 0) {
      final cashoutY = rect.bottom -
          ((cashoutMultiplier! - 1.0) / (maxY - 1.0)) * rect.height;

      final dashPaint = Paint()
        ..color = AppTheme.winGreen.withAlpha(150)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      // Dashed line
      final dashPath = Path();
      const dashWidth = 6.0;
      const dashSpace = 4.0;
      double startX = rect.left;
      while (startX < rect.right) {
        dashPath.moveTo(startX, cashoutY);
        dashPath.lineTo(math.min(startX + dashWidth, rect.right), cashoutY);
        startX += dashWidth + dashSpace;
      }
      canvas.drawPath(dashPath, dashPaint);
    }
  }

  void _drawMultiplierText(Canvas canvas, Size size) {
    // Large multiplier display in center
    String text;
    Color textColor;
    double fontSize;

    if (phase == GamePhase.crashed) {
      text = '${currentMultiplier.toStringAsFixed(2)}x';
      textColor = AppTheme.lossRed;
      fontSize = 48;
    } else if (phase == GamePhase.cashedOut && cashoutMultiplier != null) {
      text = '${cashoutMultiplier!.toStringAsFixed(2)}x';
      textColor = AppTheme.winGreen;
      fontSize = 48;
    } else if (phase == GamePhase.running) {
      text = '${currentMultiplier.toStringAsFixed(2)}x';
      textColor = currentMultiplier < 2.0
          ? AppTheme.winGreen
          : currentMultiplier < 5.0
              ? AppTheme.multiplierYellow
              : AppTheme.lossRed;
      fontSize = 56;
    } else if (phase == GamePhase.betting) {
      text = 'STARTING...';
      textColor = AppTheme.textSecondary;
      fontSize = 32;
    } else {
      text = 'WAITING';
      textColor = AppTheme.textMuted;
      fontSize = 28;
    }

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: textColor,
          shadows: [
            Shadow(
              color: textColor.withAlpha(80),
              blurRadius: 20,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(
      canvas,
      Offset(
        (size.width - tp.width) / 2,
        (size.height - tp.height) / 2 - 20,
      ),
    );

    // Status text below multiplier
    String? statusText;
    if (phase == GamePhase.crashed) {
      statusText = 'CRASHED';
    } else if (phase == GamePhase.cashedOut) {
      statusText = 'CASHED OUT';
    }

    if (statusText != null) {
      final statusTp = TextPainter(
        text: TextSpan(
          text: statusText,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textColor.withAlpha(200),
            letterSpacing: 3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      statusTp.paint(
        canvas,
        Offset(
          (size.width - statusTp.width) / 2,
          (size.height + tp.height) / 2 - 10,
        ),
      );
    }
  }

  List<double> _calculateGridSteps(double min, double max, int targetSteps) {
    final range = max - min;
    final rawStep = range / targetSteps;
    final magnitude = math.pow(10, (math.log(rawStep) / math.ln10).floor());
    final residual = rawStep / magnitude;

    double niceStep;
    if (residual <= 1.5) {
      niceStep = 1 * magnitude.toDouble();
    } else if (residual <= 3.0) {
      niceStep = 2 * magnitude.toDouble();
    } else if (residual <= 7.0) {
      niceStep = 5 * magnitude.toDouble();
    } else {
      niceStep = 10 * magnitude.toDouble();
    }

    final steps = <double>[];
    double value = (min / niceStep).ceil() * niceStep;
    while (value <= max) {
      steps.add(value);
      value += niceStep;
    }
    return steps;
  }

  @override
  bool shouldRepaint(_CrashGraphPainter old) =>
      old.currentMultiplier != currentMultiplier ||
      old.phase != phase ||
      old.points.length != points.length ||
      old.cashoutMultiplier != cashoutMultiplier;
}
