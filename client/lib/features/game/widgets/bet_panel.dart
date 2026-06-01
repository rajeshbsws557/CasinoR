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
import 'package:crash_game/core/widgets/glass_container.dart';

class BetPanel extends StatelessWidget {
  const BetPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        SingleBetCard(index: 0),
        SizedBox(height: 8),
        SingleBetCard(index: 1),
      ],
    );
  }
}

class SingleBetCard extends StatefulWidget {
  final int index;
  const SingleBetCard({super.key, required this.index});

  @override
  State<SingleBetCard> createState() => _SingleBetCardState();
}

class _SingleBetCardState extends State<SingleBetCard> {
  // Default bet in TAKA (user types taka, we convert to paisa before sending)
  final _amountController = TextEditingController(text: '10');
  final _autoCashoutController = TextEditingController();

  String? _myBetId;
  bool _isPendingPlacement = false;

  @override
  void dispose() {
    _amountController.dispose();
    _autoCashoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameBloc, GameState>(
      listenWhen: (previous, current) {
        // Claim the newest bet if we were waiting for it
        if (_isPendingPlacement && previous.myBets.length < current.myBets.length) {
          final newBet = current.myBets.last;
          if (_myBetId == null) {
            _myBetId = newBet.betId;
            _isPendingPlacement = false;
          }
        }
        // Reset when a new round starts
        if (previous.phase != GamePhase.betting && current.phase == GamePhase.betting) {
          _myBetId = null;
          _isPendingPlacement = false;
        }
        return false;
      },
      listener: (context, state) {},
      builder: (context, gameState) {
        return BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            final balance = authState is AuthAuthenticated
                ? authState.user.balance
                : 0;

            final isBettingPhase = gameState.phase == GamePhase.betting;
            final isRunning = gameState.phase == GamePhase.running;
            
            MyBetState? myBetData;
            if (_myBetId != null) {
              try {
                myBetData = gameState.myBets.firstWhere((b) => b.betId == _myBetId);
              } catch (_) {}
            }

            final hasActiveBet = myBetData != null && !myBetData.isCashedOut;
            final canBet = isBettingPhase && !hasActiveBet && !_isPendingPlacement;
            final canCashout = isRunning && hasActiveBet;
            final isCashedOut = myBetData?.isCashedOut ?? false;

            return GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Amount (৳)',
                            prefixText: '৳ ',
                            prefixStyle: GoogleFonts.jetBrainsMono(
                              color: AppTheme.accentPurple,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _QuickButton(
                        label: '½',
                        enabled: canBet,
                        onTap: () {
                          final current = int.tryParse(_amountController.text) ?? 0;
                          _amountController.text = (current ~/ 2).clamp(1, 999999).toString();
                        },
                      ),
                      const SizedBox(width: 4),
                      _QuickButton(
                        label: '2×',
                        enabled: canBet,
                        onTap: () {
                          final current = int.tryParse(_amountController.text) ?? 0;
                          _amountController.text = (current * 2).clamp(1, 999999).toString();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _autoCashoutController,
                          enabled: canBet,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: GoogleFonts.jetBrainsMono(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Auto Cashout',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 48,
                          child: canCashout
                              ? _buildCashoutButton(context, gameState, myBetData!)
                              : isCashedOut 
                                  ? _buildCashedOutState(myBetData!)
                                  : _buildBetButton(context, canBet),
                        ),
                      ),
                    ],
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
    if (_isPendingPlacement) {
      enabled = false;
    }
    return Container(
      decoration: BoxDecoration(
        gradient: enabled ? AppTheme.accentGradient : null,
        color: enabled ? null : AppTheme.border,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ElevatedButton(
        onPressed: enabled ? () => _placeBet(context) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _isPendingPlacement ? 'WAIT...' : 'BET',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: enabled ? Colors.white : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCashoutButton(BuildContext context, GameState gameState, MyBetState myBet) {
    // Display potential win in TAKA (divide paisa by 100)
    final potentialWinPaisa = myBet.amount * gameState.currentMultiplier;
    final potentialWinTaka = potentialWinPaisa / 100;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.winGreen,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppTheme.winGreen.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          SoundManager().playCashout();
          context.read<GameBloc>().add(GameCashout(myBet.betId));
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'CASH OUT',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: AppTheme.background,
                ),
              ),
              Text(
                '৳${potentialWinTaka.toStringAsFixed(2)}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.background.withAlpha(200),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCashedOutState(MyBetState myBet) {
    // Display win amount in TAKA
    final winAmountPaisa = (myBet.amount + (myBet.cashoutProfit ?? 0));
    final winAmountTaka = winAmountPaisa / 100;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.winGreen.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.winGreen.withOpacity(0.5)),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'WON ৳${winAmountTaka.toStringAsFixed(2)}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.winGreen,
            ),
          ),
        ),
      ),
    );
  }

  void _placeBet(BuildContext context) {
    final amountTaka = int.tryParse(_amountController.text);
    if (amountTaka == null || amountTaka <= 0) return;

    // Convert TAKA to PAISA before sending to server
    final amountPaisa = amountTaka * 100;

    double? autoCashout;
    if (_autoCashoutController.text.isNotEmpty) {
      autoCashout = double.tryParse(_autoCashoutController.text);
    }

    HapticFeedback.lightImpact();
    SoundManager().playBet();

    context.read<GameBloc>().add(GamePlaceBet(
      amount: amountPaisa,
      autoCashout: autoCashout,
    ));

    setState(() => _isPendingPlacement = true);
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
          color: enabled ? AppTheme.surface.withOpacity(0.5) : AppTheme.border.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
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
