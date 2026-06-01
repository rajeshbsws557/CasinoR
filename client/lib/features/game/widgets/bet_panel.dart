// ============================================
// Bet Panel — Bet Input & Cashout Button
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:crash_game/config/theme.dart';
import 'package:crash_game/features/auth/bloc/auth_bloc.dart';
import 'package:crash_game/features/game/bloc/game_bloc.dart';
import 'package:crash_game/core/audio/sound_manager.dart';

class BetPanel extends StatefulWidget {
  const BetPanel({super.key});

  @override
  State<BetPanel> createState() => _BetPanelState();
}

class _BetPanelState extends State<BetPanel> with SingleTickerProviderStateMixin {
  final _amountController = TextEditingController(text: '100');
  final _autoCashoutController = TextEditingController();
  bool _hasActiveBet = false;

  @override
  void dispose() {
    _amountController.dispose();
    _autoCashoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      builder: (context, gameState) {
        return BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            final balance = authState is AuthAuthenticated
                ? authState.user.balance
                : 0;

            final isBettingPhase = gameState.phase == GamePhase.betting;
            final isRunning = gameState.phase == GamePhase.running;
            final canBet = isBettingPhase && !_hasActiveBet;
            final canCashout = isRunning && _hasActiveBet;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Balance display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Balance',
                        style: GoogleFonts.inter(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '৳${(balance / 100).toStringAsFixed(2)}',
                        style: GoogleFonts.jetBrainsMono(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Bet amount input with quick buttons
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _amountController,
                          enabled: canBet,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: GoogleFonts.jetBrainsMono(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Amount (paisa)',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _QuickButton(
                        label: '½',
                        enabled: canBet,
                        onTap: () {
                          final current = int.tryParse(_amountController.text) ?? 0;
                          _amountController.text = (current ~/ 2).toString();
                        },
                      ),
                      const SizedBox(width: 4),
                      _QuickButton(
                        label: '2×',
                        enabled: canBet,
                        onTap: () {
                          final current = int.tryParse(_amountController.text) ?? 0;
                          _amountController.text = (current * 2).toString();
                        },
                      ),
                      const SizedBox(width: 4),
                      _QuickButton(
                        label: 'Max',
                        enabled: canBet,
                        onTap: () {
                          _amountController.text = balance.toString();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Auto-cashout input
                  TextField(
                    controller: _autoCashoutController,
                    enabled: canBet,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.jetBrainsMono(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Auto Cashout (e.g. 2.0)',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Main action button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: canCashout
                        ? _buildCashoutButton(context, gameState)
                        : _buildBetButton(context, canBet),
                  ),

                  // Error message
                  if (gameState.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        gameState.errorMessage!,
                        style: GoogleFonts.inter(
                          color: AppTheme.lossRed,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBetButton(BuildContext context, bool enabled) {
    return Container(
      decoration: BoxDecoration(
        gradient: enabled ? AppTheme.accentGradient : null,
        color: enabled ? null : AppTheme.border,
        borderRadius: BorderRadius.circular(12),
        boxShadow: enabled
            ? [BoxShadow(
                color: AppTheme.accentPurple.withAlpha(80),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )]
            : null,
      ),
      child: ElevatedButton(
        onPressed: enabled ? () => _placeBet(context) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'PLACE BET',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: enabled ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildCashoutButton(BuildContext context, GameState gameState) {
    final potentialWin = (int.tryParse(_amountController.text) ?? 0) *
        gameState.currentMultiplier;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.winGreen,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.winGreen.withAlpha(100),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          SoundManager().playCashout();
          context.read<GameBloc>().add(GameCashout());
          setState(() => _hasActiveBet = false);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'CASH OUT',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: AppTheme.background,
              ),
            ),
            Text(
              '৳${(potentialWin / 100).toStringAsFixed(2)}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.background.withAlpha(200),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _placeBet(BuildContext context) {
    final amount = int.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    double? autoCashout;
    if (_autoCashoutController.text.isNotEmpty) {
      autoCashout = double.tryParse(_autoCashoutController.text);
    }

    HapticFeedback.lightImpact();
    SoundManager().playBet();

    context.read<GameBloc>().add(GamePlaceBet(
      amount: amount,
      autoCashout: autoCashout,
    ));

    setState(() => _hasActiveBet = true);
  }
}

class _QuickButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _QuickButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? AppTheme.surface : AppTheme.border.withAlpha(50),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: enabled ? AppTheme.textPrimary : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}
