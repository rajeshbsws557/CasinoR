// ============================================
// Bet Leaderboard — All Bets / Previous / Top
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:crash_game/config/theme.dart';
import 'package:crash_game/features/game/bloc/game_bloc.dart';

class BetLeaderboard extends StatefulWidget {
  const BetLeaderboard({super.key});

  @override
  State<BetLeaderboard> createState() => _BetLeaderboardState();
}

class _BetLeaderboardState extends State<BetLeaderboard> {
  int _activeTab = 0; // 0 = All Bets, 1 = Previous, 2 = Top

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      buildWhen: (prev, curr) =>
          prev.activeBets != curr.activeBets ||
          prev.previousRoundBets != curr.previousRoundBets ||
          prev.topWins != curr.topWins,
      builder: (context, state) {
        List<Map<String, dynamic>> displayBets;
        switch (_activeTab) {
          case 1:
            displayBets = state.previousRoundBets;
            break;
          case 2:
            displayBets = state.topWins;
            break;
          default:
            displayBets = state.activeBets;
        }

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─── Tab Bar ───
              _buildTabBar(),

              // ─── Stats Row ───
              if (_activeTab == 0) _buildStatsRow(state),

              // ─── Header Row ───
              _buildHeaderRow(),

              // ─── Bet List ───
              if (displayBets.isEmpty)
                _buildEmptyState()
              else
                ...displayBets.take(15).map((bet) => _buildBetRow(bet)),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBar() {
    const labels = ['All Bets', 'Previous', 'Top'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.card.withOpacity(0.5),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final isActive = _activeTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = index),
              child: Container(
                height: 34,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[index],
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? AppTheme.textPrimary : AppTheme.textMuted,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStatsRow(GameState state) {
    // Calculate total bets and total win
    final totalBets = state.activeBets.length;
    final cashedOutBets = state.activeBets.where((b) => b['status'] == 'cashed_out').toList();
    final totalWin = cashedOutBets.fold<double>(0.0, (sum, b) {
      final amount = (b['amount'] as num?)?.toDouble() ?? 0;
      final profit = (b['profit'] as num?)?.toDouble() ?? 0;
      return sum + amount + profit;
    }) / 100; // Convert paisa to taka

    final progress = totalBets > 0
        ? cashedOutBets.length / totalBets
        : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          // Bet count + avatars
          Row(
            children: [
              // Stacked avatar emojis (cosmetic)
              SizedBox(
                width: 40,
                height: 24,
                child: Stack(
                  children: [
                    Positioned(left: 0, child: Text('🪙', style: TextStyle(fontSize: 14))),
                    Positioned(left: 10, child: Text('🎰', style: TextStyle(fontSize: 14))),
                    Positioned(left: 20, child: Text('🎲', style: TextStyle(fontSize: 14))),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${cashedOutBets.length}/$totalBets Bets',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Progress bar
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppTheme.card,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.winGreen),
                minHeight: 5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Total win
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatAmount(totalWin),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                'Total win BDT',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.border.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'Player',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Bet BDT',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'X',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Win BDT',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBetRow(Map<String, dynamic> bet) {
    final username = bet['username'] as String? ?? '???';
    final maskedName = _maskUsername(username);
    final amount = ((bet['amount'] as num?)?.toDouble() ?? 0) / 100;
    final status = bet['status'] as String? ?? 'active';
    final isCashedOut = status == 'cashed_out';
    final multiplier = (bet['cashoutMultiplier'] as num?)?.toDouble();
    final profit = (bet['profit'] as num?)?.toDouble() ?? 0;
    final winAmount = isCashedOut ? (amount + profit / 100) : 0.0;

    // Generate deterministic avatar emoji from username
    final avatarEmoji = _getAvatarEmoji(username);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCashedOut 
            ? AppTheme.winGreen.withOpacity(0.03)
            : Colors.transparent,
        border: Border(
          bottom: BorderSide(color: AppTheme.border.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          // Player
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.card,
                    border: Border.all(color: AppTheme.border.withOpacity(0.3)),
                  ),
                  alignment: Alignment.center,
                  child: Text(avatarEmoji, style: const TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    maskedName,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bet amount
          Expanded(
            flex: 3,
            child: Text(
              _formatAmount(amount),
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          // Multiplier
          Expanded(
            flex: 2,
            child: Text(
              isCashedOut && multiplier != null
                  ? '${multiplier.toStringAsFixed(2)}x'
                  : '—',
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isCashedOut
                    ? (multiplier != null && multiplier >= 2.0
                        ? AppTheme.accentPurple
                        : AppTheme.winGreen)
                    : AppTheme.textMuted,
              ),
            ),
          ),
          // Win amount
          Expanded(
            flex: 3,
            child: Text(
              isCashedOut ? _formatAmount(winAmount) : '—',
              textAlign: TextAlign.right,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isCashedOut ? AppTheme.textPrimary : AppTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          _activeTab == 0
              ? 'No bets yet this round'
              : _activeTab == 1
                  ? 'No previous round data'
                  : 'No top wins yet',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  // ─── Helpers ───

  String _maskUsername(String username) {
    if (username.length <= 2) return '${username[0]}***';
    return '${username[0]}***${username[username.length - 1]}';
  }

  String _getAvatarEmoji(String username) {
    const emojis = ['🎯', '🎲', '🎰', '🪙', '💎', '🔥', '⭐', '🎪', '🏆', '🎮', '🐉', '🦁'];
    final index = username.codeUnits.fold<int>(0, (sum, c) => sum + c) % emojis.length;
    return emojis[index];
  }

  String _formatAmount(double amount) {
    if (amount >= 1000) {
      return amount.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
    }
    return amount.toStringAsFixed(2);
  }
}
