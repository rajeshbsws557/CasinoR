// ============================================
// Game History Bar — Recent Crash Points
// ============================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:crash_game/config/theme.dart';

class GameHistoryBar extends StatelessWidget {
  final List<double> crashPoints;

  const GameHistoryBar({super.key, required this.crashPoints});

  @override
  Widget build(BuildContext context) {
    if (crashPoints.isEmpty) {
      return const SizedBox(height: 36);
    }

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true, // Show newest first
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: crashPoints.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final cp = crashPoints[crashPoints.length - 1 - index];
          final isGreen = cp >= 2.0;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (isGreen ? AppTheme.winGreen : AppTheme.lossRed).withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (isGreen ? AppTheme.winGreen : AppTheme.lossRed).withAlpha(60),
              ),
            ),
            child: Text(
              '${cp.toStringAsFixed(2)}x',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isGreen ? AppTheme.winGreen : AppTheme.lossRed,
              ),
            ),
          );
        },
      ),
    );
  }
}
