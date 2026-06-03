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
  final _betAmountController = TextEditingController(text: '10.00');
  final _autoCashoutController = TextEditingController();

  double get _betAmount => double.tryParse(_betAmountController.text) ?? 10.0;

  bool _isPendingPlacement = false;
  bool _isAutoBetEnabled = false;
  bool _isNextRoundBetQueued = false;
  bool _showAutoTab = false;
  bool _autoCashoutEnabled = false;

  @override
  void dispose() {
    _betAmountController.dispose();
    _autoCashoutController.dispose();
    super.dispose();
  }

  void _adjustAmount(double delta) {
    final current = _betAmount;
    final newAmount = (current + delta).clamp(1.0, 999999.0);
    setState(() {
      _betAmountController.text = newAmount.toStringAsFixed(2);
    });
  }

  void _setAmount(double amount) {
    setState(() {
      _betAmountController.text = amount.toStringAsFixed(2);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // Listen for new round starts to auto-bet
        BlocListener<GameBloc, GameState>(
          listenWhen: (previous, current) {
            return previous.phase != GamePhase.betting &&
                current.phase == GamePhase.betting;
          },
          listener: (context, state) {
            setState(() => _isPendingPlacement = false);

            if (_isNextRoundBetQueued || _isAutoBetEnabled) {
              _isNextRoundBetQueued = false;
              Future.microtask(() {
                if (mounted && context.mounted) {
                  _placeBet(context, force: true);
                }
              });
            }
          },
        ),
        // Listen for bet errors targeting THIS panel
        BlocListener<GameBloc, GameState>(
          listenWhen: (previous, current) {
            return current.errorMessage != null &&
                current.errorMessage != previous.errorMessage;
          },
          listener: (context, state) {
            // Reset pending state on any error (the GameBetError event
            // also fires, but we catch it here as a safety net)
            if (_isPendingPlacement) {
              setState(() => _isPendingPlacement = false);
            }
          },
        ),
      ],
      child: BlocBuilder<GameBloc, GameState>(
        builder: (context, gameState) {
          return BlocBuilder<AuthBloc, AuthState>(
            builder: (context, authState) {
              final isBettingPhase = gameState.phase == GamePhase.betting;
              final isRunning = gameState.phase == GamePhase.running;

              // Find THIS panel's bet
              MyBetState? myBetData;
              try {
                myBetData = gameState.myBets
                    .firstWhere((b) => b.panelId == widget.index);
                if (_isPendingPlacement) {
                  Future.microtask(() {
                    if (mounted) setState(() => _isPendingPlacement = false);
                  });
                }
              } catch (_) {}

              final hasActiveBet =
                  myBetData != null && !myBetData.isCashedOut;
              final canBet = !hasActiveBet && !_isPendingPlacement;
              final canCashout = isRunning && hasActiveBet;
              final isCashedOut = myBetData?.isCashedOut ?? false;

              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppTheme.border.withOpacity(0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Left: Amount + Presets + Auto controls ──
                    Expanded(
                      flex: 5,
                      child: _buildLeftSection(context, canBet),
                    ),
                    const SizedBox(width: 10),
                    // ── Right: Tabs + Action Button ──
                    SizedBox(
                      width: 130,
                      child: _buildRightSection(
                        context,
                        gameState,
                        canBet,
                        canCashout,
                        isCashedOut,
                        isBettingPhase,
                        myBetData,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLeftSection(BuildContext context, bool canBet) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Amount Row: [ - ]  Amount  [ + ] ──
        _buildAmountRow(canBet),
        const SizedBox(height: 6),

        // ── Presets: 2x2 grid ──
        Row(
          children: [
            Expanded(child: _buildPresetButton(0.50, canBet)),
            const SizedBox(width: 6),
            Expanded(child: _buildPresetButton(40.00, canBet)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _buildPresetButton(380.00, canBet)),
            const SizedBox(width: 6),
            Expanded(child: _buildPresetButton(3000.00, canBet)),
          ],
        ),
        const SizedBox(height: 6),

        // ── MAX Button ──
        GestureDetector(
          onTap: canBet
              ? () {
                  final authState = context.read<AuthBloc>().state;
                  final balance = authState is AuthAuthenticated
                      ? authState.user.balance / 100
                      : 0.0;
                  _setAmount(balance);
                }
              : null,
          child: Container(
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.border.withOpacity(0.3)),
            ),
            alignment: Alignment.center,
            child: Text(
              'MAX',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: canBet
                    ? AppTheme.textMuted
                    : AppTheme.textMuted.withOpacity(0.5),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // ── Bottom Row: Autoplay + Auto Cash Out ──
        Row(
          children: [
            // Autoplay button
            GestureDetector(
              onTap: canBet
                  ? () {
                      setState(() {
                        _isAutoBetEnabled = !_isAutoBetEnabled;
                      });
                    }
                  : null,
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _isAutoBetEnabled
                      ? const Color(0xFF0D84E7)
                      : const Color(0xFF0D84E7).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Autoplay',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Auto Cash Out toggle + input
            Expanded(
              child: Row(
                children: [
                  Text(
                    'Auto C/O',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 28,
                    height: 16,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Switch(
                        value: _autoCashoutEnabled,
                        onChanged: canBet
                            ? (val) {
                                setState(() {
                                  _autoCashoutEnabled = val;
                                  if (val && _autoCashoutController.text.isEmpty) {
                                    _autoCashoutController.text = '1.50';
                                  }
                                  if (!val) {
                                    _autoCashoutController.clear();
                                  }
                                });
                              }
                            : null,
                        activeColor: Colors.white,
                        activeTrackColor: const Color(0xFF10A814),
                        inactiveTrackColor: AppTheme.surface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 44,
                    height: 22,
                    child: TextField(
                      controller: _autoCashoutController,
                      enabled: canBet && _autoCashoutEnabled,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: _autoCashoutEnabled
                            ? AppTheme.textPrimary
                            : AppTheme.textMuted,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        suffixText: 'x',
                        suffixStyle: GoogleFonts.inter(
                            fontSize: 9, color: AppTheme.textMuted),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(
                              color: AppTheme.border.withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(
                              color: AppTheme.border.withOpacity(0.3)),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(
                              color: AppTheme.border.withOpacity(0.15)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRightSection(
    BuildContext context,
    GameState gameState,
    bool canBet,
    bool canCashout,
    bool isCashedOut,
    bool isBettingPhase,
    MyBetState? myBetData,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Tabs: Bet | Auto ──
        Container(
          height: 26,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.25),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showAutoTab = false),
                  child: Container(
                    decoration: BoxDecoration(
                      color: !_showAutoTab
                          ? AppTheme.surface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Bet',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: !_showAutoTab
                            ? AppTheme.textPrimary
                            : AppTheme.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showAutoTab = true),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _showAutoTab
                          ? AppTheme.surface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Auto',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _showAutoTab
                            ? AppTheme.textPrimary
                            : AppTheme.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // ── Action Button (fixed height, NOT expanded) ──
        SizedBox(
          height: 120,
          child: canCashout
              ? _buildCashoutButton(context, gameState, myBetData!)
              : isCashedOut
                  ? _buildCashedOutState(myBetData!)
                  : _buildBetButton(context, canBet, isBettingPhase),
        ),
      ],
    );
  }

  // ── Amount Row ──

  Widget _buildAmountRow(bool canBet) {
    return Row(
      children: [
        _CircleButton(
          icon: Icons.remove,
          onTap: canBet ? () => _adjustAmount(-1.0) : null,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            height: 34,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.border.withOpacity(0.4)),
            ),
            alignment: Alignment.center,
            child: TextField(
              controller: _betAmountController,
              enabled: canBet,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: canBet ? AppTheme.textPrimary : AppTheme.textMuted,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (val) => setState(() {}),
            ),
          ),
        ),
        const SizedBox(width: 6),
        _CircleButton(
          icon: Icons.add,
          onTap: canBet ? () => _adjustAmount(1.0) : null,
        ),
      ],
    );
  }

  // ── Preset Button ──

  Widget _buildPresetButton(double amount, bool canBet) {
    final label = amount >= 1000
        ? '${(amount / 1000).toStringAsFixed(0)},${(amount % 1000).toInt().toString().padLeft(3, '0')}'
        : amount.toStringAsFixed(2);

    return GestureDetector(
      onTap: canBet ? () => _setAmount(amount) : null,
      child: Container(
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.border.withOpacity(0.3)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: canBet
                ? AppTheme.textMuted
                : AppTheme.textMuted.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  // ── Bet Button ──

  Widget _buildBetButton(
      BuildContext context, bool enabled, bool isBettingPhase) {
    if (_isPendingPlacement) enabled = false;

    String btnLabel = 'BET';
    String btnAmount = _betAmount.toStringAsFixed(2);
    bool isCancel = false;

    if (_isPendingPlacement) {
      btnLabel = 'WAITING';
      btnAmount = '';
    } else if (_showAutoTab && _isAutoBetEnabled) {
      btnLabel = 'AUTO BET';
    } else if (_isNextRoundBetQueued) {
      btnLabel = 'CANCEL';
      btnAmount = '';
      isCancel = true;
    } else if (!isBettingPhase) {
      btnLabel = 'BET (NEXT)';
    }

    return GestureDetector(
      onTap: (enabled || isCancel)
          ? () {
              if (isCancel) {
                setState(() => _isNextRoundBetQueued = false);
              } else {
                _placeBet(context, force: isBettingPhase);
              }
            }
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: isCancel
              ? AppTheme.lossRed
              : (enabled
                  ? const Color(0xFF10A814)
                  : const Color(0xFF10A814).withOpacity(0.35)),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              btnLabel,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            if (btnAmount.isNotEmpty)
              Text(
                btnAmount,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Cashout Button ──

  Widget _buildCashoutButton(
      BuildContext context, GameState gameState, MyBetState myBet) {
    final potentialWinPaisa = myBet.amount * gameState.currentMultiplier;
    final potentialWinTaka = potentialWinPaisa / 100;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        SoundManager().playCashout();
        context.read<GameBloc>().add(GameCashout(myBet.betId));
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE28B0A),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'CASH OUT',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              '৳${potentialWinTaka.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Cashed Out State ──

  Widget _buildCashedOutState(MyBetState myBet) {
    final winAmountPaisa = myBet.amount + (myBet.cashoutProfit ?? 0);
    final winAmountTaka = winAmountPaisa / 100;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF10A814).withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF10A814).withOpacity(0.4)),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'WON',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF10A814),
            ),
          ),
          Text(
            '৳${winAmountTaka.toStringAsFixed(2)}',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF10A814),
            ),
          ),
        ],
      ),
    );
  }

  // ── Place Bet Logic ──

  void _placeBet(BuildContext context, {bool force = false}) {
    if (_betAmount <= 0) return;

    final gameState = context.read<GameBloc>().state;
    if (!force && gameState.phase != GamePhase.betting) {
      setState(() => _isNextRoundBetQueued = true);
      return;
    }

    final amountPaisa = (_betAmount * 100).toInt();

    double? autoCashout;
    if (_autoCashoutEnabled && _autoCashoutController.text.isNotEmpty) {
      autoCashout = double.tryParse(_autoCashoutController.text);
    }

    HapticFeedback.lightImpact();
    SoundManager().playBet();

    context.read<GameBloc>().add(GamePlaceBet(
          amount: amountPaisa,
          panelId: widget.index,
          autoCashout: autoCashout,
        ));

    setState(() => _isPendingPlacement = true);
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
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.surface.withOpacity(0.8),
          border: Border.all(color: AppTheme.border.withOpacity(0.3)),
        ),
        child: Icon(
          icon,
          size: 14,
          color: onTap != null ? AppTheme.textPrimary : AppTheme.textMuted,
        ),
      ),
    );
  }
}
