// ============================================
// Crash Graph — CustomPainter Visualization
// ============================================

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:crash_game/config/theme.dart';
import 'package:crash_game/features/game/bloc/game_bloc.dart';

class CrashGraph extends StatefulWidget {
  final List<double> multiplierHistory;
  final double currentMultiplier;
  final GamePhase phase;
  final double? cashoutMultiplier;
  final int? cashoutProfit;
  final int? betAmount;

  const CrashGraph({
    super.key,
    required this.multiplierHistory,
    required this.currentMultiplier,
    required this.phase,
    this.cashoutMultiplier,
    this.cashoutProfit,
    this.betAmount,
  });

  @override
  State<CrashGraph> createState() => _CrashGraphState();
}

class _CrashGraphState extends State<CrashGraph> with SingleTickerProviderStateMixin {
  double _visualMultiplier = 1.0;
  DateTime _lastUpdate = DateTime.now();
  late Ticker _ticker;
  ui.Image? _planeImage;

  @override
  void initState() {
    super.initState();
    _visualMultiplier = widget.currentMultiplier;
    _lastUpdate = DateTime.now();
    _ticker = createTicker(_onTick);
    if (widget.phase == GamePhase.running || widget.phase == GamePhase.cashedOut) {
      _ticker.start();
    }
    _loadPlaneImage();
  }

  Future<void> _loadPlaneImage() async {
    try {
      final data = await rootBundle.load('assets/images/plane.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: 80);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _planeImage = frame.image;
        });
      }
    } catch (e) {
      debugPrint('Failed to load plane image: $e');
    }
  }

  void _onTick(Duration elapsed) {
    if (widget.phase == GamePhase.running || widget.phase == GamePhase.cashedOut) {
      final now = DateTime.now();
      final deltaMs = now.difference(_lastUpdate).inMilliseconds;
      setState(() {
        _visualMultiplier = widget.currentMultiplier * math.exp(0.00006 * deltaMs);
      });
    } else {
      if (_ticker.isTicking) _ticker.stop();
    }
  }

  @override
  void didUpdateWidget(CrashGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentMultiplier != oldWidget.currentMultiplier) {
      _lastUpdate = DateTime.now();
      _visualMultiplier = widget.currentMultiplier;
    }
    
    final isRunningPhase = widget.phase == GamePhase.running || widget.phase == GamePhase.cashedOut;
    
    if (isRunningPhase && !_ticker.isTicking) {
      _lastUpdate = DateTime.now();
      _ticker.start();
    } else if (!isRunningPhase && _ticker.isTicking) {
      _ticker.stop();
      _visualMultiplier = widget.currentMultiplier;
    }
    
    if (!isRunningPhase) {
      _visualMultiplier = widget.currentMultiplier;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<double> visualPoints = List.from(widget.multiplierHistory);
    final isRunningPhase = widget.phase == GamePhase.running || widget.phase == GamePhase.cashedOut;
    if (isRunningPhase && _visualMultiplier > 1.0) {
       visualPoints.add(_visualMultiplier);
    }

    return RepaintBoundary(
      child: CustomPaint(
        painter: _CrashGraphPainter(
          points: visualPoints,
          currentMultiplier: _visualMultiplier,
          phase: widget.phase,
          cashoutMultiplier: widget.cashoutMultiplier,
          cashoutProfit: widget.cashoutProfit,
          betAmount: widget.betAmount,
          planeImage: _planeImage,
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
  final int? cashoutProfit;
  final int? betAmount;
  final ui.Image? planeImage;

  _CrashGraphPainter({
    required this.points,
    required this.currentMultiplier,
    required this.phase,
    this.cashoutMultiplier,
    this.cashoutProfit,
    this.betAmount,
    this.planeImage,
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

    // Draw grid
    _drawGrid(canvas, graphRect);

    // Draw curve
    if (points.isNotEmpty) {
      _drawCurve(canvas, graphRect);
    }

    // Draw multiplier text
    _drawMultiplierText(canvas, size);

    // Draw cashout badge in corner (not blocking graph)
    if (phase == GamePhase.cashedOut && cashoutMultiplier != null) {
      _drawCashoutBadge(canvas, size);
    }
  }

  void _drawGrid(Canvas canvas, Rect rect) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1.0;

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
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 2.0;
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
      ..strokeWidth = 4
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
          curveColor.withOpacity(0.4),
          curveColor.withOpacity(0.0),
        ],
      );
    canvas.drawPath(fillPath, fillPaint);

    // Draw airplane at curve tip (instead of a dot)
    if (phase == GamePhase.running || phase == GamePhase.cashedOut) {
      final lastPt = Offset(
        lastX,
        rect.bottom - ((points.last - 1.0) / (maxY - 1.0)) * rect.height,
      );

      // Calculate trajectory angle from last 2 points
      double angle = -math.pi / 4; // Default: 45 degrees up-right
      if (points.length >= 2) {
        final prevIdx = points.length - 2;
        final prevX = rect.left + (prevIdx / math.max(points.length - 1, 1)) * rect.width;
        final prevNY = (points[prevIdx] - 1.0) / (maxY - 1.0);
        final prevY = rect.bottom - prevNY * rect.height;
        angle = math.atan2(lastPt.dy - prevY, lastPt.dx - prevX);
      }

      // Draw thruster/exhaust glow trail behind the plane
      canvas.save();
      canvas.translate(lastPt.dx, lastPt.dy);
      canvas.rotate(angle);

      // Exhaust flame trail (behind the plane, i.e. negative x direction)
      final exhaustPaint = Paint()
        ..shader = ui.Gradient.linear(
          const Offset(-40, 0),
          const Offset(0, 0),
          [
            curveColor.withOpacity(0.0),
            curveColor.withOpacity(0.5),
            Colors.white.withOpacity(0.8),
          ],
          [0.0, 0.6, 1.0],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      final exhaustPath = Path()
        ..moveTo(-35, -5)
        ..quadraticBezierTo(-18, 0, -5, 0)
        ..quadraticBezierTo(-18, 0, -35, 5)
        ..close();
      canvas.drawPath(exhaustPath, exhaustPaint);

      // Outer glow around plane
      final planeGlowPaint = Paint()
        ..color = curveColor.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(Offset.zero, 16, planeGlowPaint);

      canvas.restore();

      canvas.save();
      canvas.translate(lastPt.dx, lastPt.dy);
      canvas.rotate(angle + math.pi / 4); // Adjust for rotation

      if (planeImage != null) {
        // Draw the image using BlendMode.screen to make the pure black background invisible
        final paint = Paint()
           ..blendMode = BlendMode.screen
           ..isAntiAlias = true
           ..filterQuality = FilterQuality.high;
           
        final offset = Offset(-planeImage!.width / 2, -planeImage!.height / 2);
        canvas.drawImage(planeImage!, offset, paint);
      } else {
        // Fallback to emoji
        final planeTp = TextPainter(
          text: TextSpan(
            text: '✈',
            style: TextStyle(
              fontSize: 26,
              color: Colors.white,
              shadows: [
                Shadow(color: curveColor, blurRadius: 12),
                Shadow(color: curveColor.withAlpha(120), blurRadius: 24),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        planeTp.paint(canvas, Offset(-planeTp.width / 2, -planeTp.height / 2));
      }
      
      canvas.restore();
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
    } else if (phase == GamePhase.cashedOut) {
      // When cashed out, still show the LIVE multiplier so the graph isn't blocked
      text = '${currentMultiplier.toStringAsFixed(2)}x';
      textColor = currentMultiplier < 2.0
          ? AppTheme.winGreen
          : currentMultiplier < 5.0
              ? AppTheme.multiplierYellow
              : AppTheme.lossRed;
      fontSize = 56;
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
          fontFamily: 'Outfit',
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

    // Status text below multiplier — only for CRASHED (not cashedOut, since that uses a badge now)
    if (phase == GamePhase.crashed) {
      final statusTp = TextPainter(
        text: TextSpan(
          text: 'CRASHED',
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

  /// Draws a compact cashout badge in the top-right corner instead of blocking the graph
  void _drawCashoutBadge(Canvas canvas, Size size) {
    final badgeText = '✓ Cashed Out @ ${cashoutMultiplier!.toStringAsFixed(2)}x';
    String winText = '';
    if (cashoutProfit != null && betAmount != null) {
      final winAmount = (betAmount! + cashoutProfit!) / 100;
      winText = ' — Won ৳${winAmount.toStringAsFixed(2)}';
    }

    final fullText = '$badgeText$winText';

    final tp = TextPainter(
      text: TextSpan(
        text: fullText,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.winGreen,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeWidth = tp.width + 20;
    final badgeHeight = tp.height + 12;
    final badgeX = size.width - badgeWidth - 16;
    const badgeY = 28.0;

    // Badge background
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(badgeX, badgeY, badgeWidth, badgeHeight),
      const Radius.circular(8),
    );

    final bgPaint = Paint()
      ..color = AppTheme.winGreen.withOpacity(0.15);
    canvas.drawRRect(bgRect, bgPaint);

    final borderPaint = Paint()
      ..color = AppTheme.winGreen.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(bgRect, borderPaint);

    tp.paint(canvas, Offset(badgeX + 10, badgeY + 6));
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
