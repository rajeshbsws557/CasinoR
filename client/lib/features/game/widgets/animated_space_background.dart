import 'dart:math';
import 'package:flutter/material.dart';
import 'package:crash_game/config/theme.dart';

class AnimatedSpaceBackground extends StatefulWidget {
  final Widget child;

  const AnimatedSpaceBackground({super.key, required this.child});

  @override
  State<AnimatedSpaceBackground> createState() => _AnimatedSpaceBackgroundState();
}

class _AnimatedSpaceBackgroundState extends State<AnimatedSpaceBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Star> _stars;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _stars = List.generate(
      50,
      (index) => _Star(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 2 + 1,
        speed: _random.nextDouble() * 0.5 + 0.1,
        brightness: _random.nextDouble() * 0.5 + 0.3,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Deep background gradient
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.5),
              radius: 1.5,
              colors: [
                Color(0xFF131A35),
                AppTheme.background,
              ],
            ),
          ),
        ),
        // Animated stars
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _SpacePainter(
                stars: _stars,
                progress: _controller.value,
              ),
            );
          },
        ),
        // The main content
        widget.child,
      ],
    );
  }
}

class _Star {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double brightness;

  _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.brightness,
  });
}

class _SpacePainter extends CustomPainter {
  final List<_Star> stars;
  final double progress;

  _SpacePainter({required this.stars, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;

    for (var star in stars) {
      // Calculate animated Y position (drifting downwards/upwards)
      double currentY = (star.y + (progress * star.speed)) % 1.0;
      
      paint.color = Colors.white.withOpacity(star.brightness);
      canvas.drawCircle(
        Offset(star.x * size.width, currentY * size.height),
        star.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpacePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
