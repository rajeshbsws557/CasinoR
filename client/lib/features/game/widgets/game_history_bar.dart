// ============================================
// Game History Bar — Recent Crash Points (Expandable)
// ============================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:crash_game/config/theme.dart';

class GameHistoryBar extends StatefulWidget {
  final List<double> crashPoints;

  const GameHistoryBar({super.key, required this.crashPoints});

  @override
  State<GameHistoryBar> createState() => _GameHistoryBarState();
}

class _GameHistoryBarState extends State<GameHistoryBar>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.crashPoints.isEmpty) {
      return const SizedBox(height: 36);
    }

    // Show the most recent items first
    final reversed = widget.crashPoints.reversed.toList();
    final visibleItems = _isExpanded ? reversed : reversed.take(6).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GestureDetector(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row with expand/collapse toggle
              Row(
                children: [
                  Text(
                    'History',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      size: 16,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Crash points as a Wrap (expands vertically)
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 250),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: _buildCrashPointsWrap(visibleItems),
                secondChild: _buildCrashPointsWrap(visibleItems),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCrashPointsWrap(List<double> items) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items.map((cp) {
        final isGreen = cp >= 2.0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (isGreen ? AppTheme.winGreen : AppTheme.lossRed).withAlpha(20),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: (isGreen ? AppTheme.winGreen : AppTheme.lossRed).withAlpha(60),
            ),
          ),
          child: Text(
            '${cp.toStringAsFixed(2)}x',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isGreen ? AppTheme.winGreen : AppTheme.lossRed,
            ),
          ),
        );
      }).toList(),
    );
  }
}
