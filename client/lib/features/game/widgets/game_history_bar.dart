// ============================================
// Game History Bar — Aviator-Style Scrollable Multipliers
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

class _GameHistoryBarState extends State<GameHistoryBar> {
  bool _isExpanded = false;

  Color _getMultiplierColor(double cp) {
    if (cp >= 10.0) return AppTheme.winGreen;
    if (cp >= 2.0) return AppTheme.accentPurple;
    return AppTheme.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.crashPoints.isEmpty) {
      return const SizedBox(height: 32);
    }

    final reversed = widget.crashPoints.reversed.toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            // Scrollable multiplier values
            Expanded(
              child: _isExpanded
                  ? _buildExpandedWrap(reversed)
                  : _buildScrollableRow(reversed),
            ),
            // Overflow dots button
            GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.surface.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border.withOpacity(0.3)),
                ),
                child: Icon(
                  _isExpanded ? Icons.close : Icons.more_horiz,
                  size: 16,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableRow(List<double> items) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      reverse: false,
      itemCount: items.length,
      separatorBuilder: (_, _i) => const SizedBox(width: 10),
      itemBuilder: (context, index) {
        final cp = items[index];
        return Center(
          child: Text(
            '${cp.toStringAsFixed(2)}x',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _getMultiplierColor(cp),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpandedWrap(List<double> items) {
    // Show in a scrollable wrap when expanded (overlay-like)
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((cp) {
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Text(
              '${cp.toStringAsFixed(2)}x',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _getMultiplierColor(cp),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
