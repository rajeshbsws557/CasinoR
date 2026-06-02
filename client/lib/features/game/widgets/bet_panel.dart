// ============================================
// Bet Panel — Aviator-Style Dual Bet Cards
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:crash_game/config/theme.dart';
import 'package:crash_game/features/auth/bloc/auth_bloc.dart';
import 'package:crash_game/features/game/bloc/game_bloc.dart';
import 'package:crash_game/core/audio/sound_manager.dart';

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
  double _betAmount = 10.0;
  final _autoCashoutController = TextEditingController();

  String? _myBetId;
  bool _isPendingPlacement = false;
  bool _isAutoBetEnabled = false;
  bool _isNextRoundBetQueued = false;
  bool _showAutoTab = false; // false = Bet tab, true = Auto tab

  @override
  void dispose() {
    _autoCashoutController.dispose();
    super.dispose();
  }

  void _adjustAmount(double delta) {
    setState(() {
      _betAmount = (_betAmount + delta).clamp(1.0, 999999.0);
    });
  }

  void _setAmount(double amount) {
    setState(() {
      _betAmount = amount;
    });
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
          
          if (_isNextRoundBetQueued || _isAutoBetEnabled) {
             _isNextRoundBetQueued = false; // reset queue
             // Automatically place the bet
             Future.microtask(() {
               if (mounted && context.mounted) {
                 _placeBet(context, force: true);
               }
             });
          }
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
            final canBet = !hasActiveBet && !_isPendingPlacement;
            final canCashout = isRunning && hasActiveBet;
            final isCashedOut = myBetData?.isCashedOut ?? false;

            return Container(
              decoration: BoxDecoration(
                color: AppTheme.surface.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border.withOpacity(0.4)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ─── Bet / Auto Tabs ───
                  _buildTabs(canBet),
                  
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: _showAutoTab
                        ? _buildAutoContent(canBet)
                        : _buildBetContent(
                            context, gameState, canBet, canCashout,
                            isCashedOut, isBettingPhase, myBetData,
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

  Widget _buildTabs(bool canBet) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card.withOpacity(0.6),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: 'Bet',
              isActive: !_showAutoTab,
              onTap: () => setState(() => _showAutoTab = false),
            ),
          ),
          Expanded(
            child: _TabButton(
              label: 'Auto',
              isActive: _showAutoTab,
              onTap: () => setState(() => _showAutoTab = true),
            ),
          ),
          // Copy/expand button (cosmetic)
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.copy_all, size: 14, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBetContent(
    BuildContext context,
    GameState gameState,
    bool canBet,
    bool canCashout,
    bool isCashedOut,
    bool isBettingPhase,
    MyBetState? myBetData,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side: Amount controls
        Expanded(
          flex: 4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // −  Amount  +
              _buildAmountRow(canBet),
              const SizedBox(height: 6),
              // Quick preset buttons
              _buildPresetButtons(canBet),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Right side: Bet / Cashout button
        Expanded(
          flex: 5,
          child: SizedBox(
            height: 90,
            child: canCashout
                ? _buildCashoutButton(context, gameState, myBetData!)
                : isCashedOut
                    ? _buildCashedOutState(myBetData!)
                    : _buildBetButton(context, canBet, isBettingPhase),
          ),
        ),
      ],
    );
  }

  Widget _buildAutoContent(bool canBet) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Auto cashout field
        TextField(
          controller: _autoCashoutController,
          enabled: canBet,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.jetBrainsMono(
            color: AppTheme.textPrimary,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            labelText: 'Auto Cashout (x)',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: AppTheme.card.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.border.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.border.withOpacity(0.3)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Auto bet toggle
        Row(
          children: [
            SizedBox(
              height: 22,
              width: 22,
              child: Checkbox(
                value: _isAutoBetEnabled,
                onChanged: canBet ? (val) {
                  setState(() {
                    _isAutoBetEnabled = val ?? false;
                  });
                } : null,
                activeColor: AppTheme.winGreen,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide(color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Auto Bet (next round)',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAmountRow(bool canBet) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppTheme.card.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // − button
          _CircleButton(
            icon: Icons.remove,
            onTap: canBet ? () => _adjustAmount(-1.0) : null,
          ),
          // Amount display
          Expanded(
            child: Center(
              child: Text(
                _betAmount.toStringAsFixed(2),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: canBet ? AppTheme.textPrimary : AppTheme.textMuted,
                ),
              ),
            ),
          ),
          // + button
          _CircleButton(
            icon: Icons.add,
            onTap: canBet ? () => _adjustAmount(1.0) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButtons(bool canBet) {
    const presets = [100, 200, 500, 10000];
    return Row(
      children: presets.map((amount) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: GestureDetector(
              onTap: canBet ? () => _setAmount(amount.toDouble()) : null,
              child: Container(
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.card.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border.withOpacity(0.3)),
                ),
                alignment: Alignment.center,
                child: Text(
                  amount >= 10000 ? '${(amount / 1000).toInt()},000' : '$amount',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: canBet ? AppTheme.textPrimary : AppTheme.textMuted,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBetButton(BuildContext context, bool enabled, bool isBettingPhase) {
    if (_isPendingPlacement) {
      enabled = false;
    }
    
    String btnLabel = 'Bet';
    String btnAmount = '${_betAmount.toStringAsFixed(2)} BDT';
    bool isCancel = false;

    if (_isPendingPlacement) {
      btnLabel = 'Waiting...';
      btnAmount = '';
    } else if (_isNextRoundBetQueued) {
      btnLabel = 'Cancel';
      btnAmount = 'Queued';
      isCancel = true;
    } else if (!isBettingPhase) {
      btnLabel = 'Bet (Next)';
      btnAmount = '${_betAmount.toStringAsFixed(2)} BDT';
    }

    return GestureDetector(
      onTap: (enabled || isCancel) ? () {
        if (isCancel) {
           setState(() {
             _isNextRoundBetQueued = false;
           });
        } else {
           _placeBet(context, force: isBettingPhase);
        }
      } : null,
      child: Container(
        decoration: BoxDecoration(
          color: isCancel
              ? AppTheme.lossRed
              : (enabled ? AppTheme.winGreen : AppTheme.winGreen.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: enabled && !isCancel ? [
            BoxShadow(
              color: AppTheme.winGreen.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              btnLabel,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            if (btnAmount.isNotEmpty)
              Text(
                btnAmount,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashoutButton(BuildContext context, GameState gameState, MyBetState myBet) {
    // Display potential win in TAKA (divide paisa by 100)
    final potentialWinPaisa = myBet.amount * gameState.currentMultiplier;
    final potentialWinTaka = potentialWinPaisa / 100;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        SoundManager().playCashout();
        context.read<GameBloc>().add(GameCashout(myBet.betId));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: AppTheme.winGreen,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.winGreen.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Cash Out',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppTheme.background,
              ),
            ),
            Text(
              '৳${potentialWinTaka.toStringAsFixed(2)}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.background.withAlpha(200),
              ),
            ),
          ],
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
        color: AppTheme.winGreen.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.winGreen.withOpacity(0.4)),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Won',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.winGreen,
            ),
          ),
          Text(
            '৳${winAmountTaka.toStringAsFixed(2)}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.winGreen,
            ),
          ),
        ],
      ),
    );
  }

  void _placeBet(BuildContext context, {bool force = false}) {
    if (_betAmount <= 0) return;
    
    final gameState = context.read<GameBloc>().state;
    if (!force && gameState.phase != GamePhase.betting) {
      // Queue for next round
      setState(() {
        _isNextRoundBetQueued = true;
      });
      return;
    }

    // Convert TAKA to PAISA before sending to server
    final amountPaisa = (_betAmount * 100).toInt();

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

// ─── Reusable Tab Button ───

class _TabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? AppTheme.textPrimary : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

// ─── Circular +/- Button ───

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CircleButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.surface.withOpacity(0.8),
          border: Border.all(color: AppTheme.border.withOpacity(0.3)),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null ? AppTheme.textPrimary : AppTheme.textMuted,
        ),
      ),
    );
  }
}
