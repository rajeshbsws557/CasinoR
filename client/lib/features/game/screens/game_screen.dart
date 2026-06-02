// ============================================
// Game Screen — Aviator-Style Main Gameplay UI
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:crash_game/config/theme.dart';
import 'package:crash_game/features/auth/bloc/auth_bloc.dart';
import 'package:crash_game/features/game/bloc/game_bloc.dart';
import 'package:crash_game/features/game/widgets/crash_graph.dart';
import 'package:crash_game/features/game/widgets/bet_panel.dart';
import 'package:crash_game/features/game/widgets/game_history_bar.dart';
import 'package:crash_game/features/game/widgets/bet_leaderboard.dart';
import 'package:crash_game/features/chat/widgets/chat_panel.dart';
import 'package:crash_game/features/game/widgets/animated_space_background.dart';

import 'package:flutter/services.dart';
import 'package:crash_game/core/audio/sound_manager.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  @override
  void initState() {
    super.initState();
    // Connect WebSocket when entering game screen
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<GameBloc>().add(GameConnectRequested(authState.token));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GameBloc, GameState>(
      listenWhen: (prev, curr) => prev.phase != curr.phase,
      listener: (context, state) {
        if (state.phase == GamePhase.crashed) {
          HapticFeedback.heavyImpact();
          SoundManager().playCrash();
        }
      },
      child: Scaffold(
      body: AnimatedSpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
            // ─── Top Bar ───
            _buildTopBar(),

            // ─── Connection Status ───
            BlocBuilder<GameBloc, GameState>(
              buildWhen: (prev, curr) => prev.phase != curr.phase,
              builder: (context, state) {
                if (state.phase == GamePhase.connecting ||
                    state.phase == GamePhase.disconnected) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    color: state.phase == GamePhase.disconnected
                        ? AppTheme.lossRed.withAlpha(30)
                        : AppTheme.accentBlue.withAlpha(30),
                    child: Text(
                      state.phase == GamePhase.disconnected
                          ? '⚠ Connection lost. Reconnecting...'
                          : '● Connecting...',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: state.phase == GamePhase.disconnected
                            ? AppTheme.lossRed
                            : AppTheme.accentBlue,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // ─── History Bar (scrollable multipliers) ───
            BlocBuilder<GameBloc, GameState>(
              buildWhen: (prev, curr) =>
                  prev.recentCrashPoints.length != curr.recentCrashPoints.length,
              builder: (context, state) {
                return GameHistoryBar(crashPoints: state.recentCrashPoints);
              },
            ),
            const SizedBox(height: 4),

            // ─── Scrollable Content ───
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // ─── Crash Graph (main visual) ───
                    BlocBuilder<GameBloc, GameState>(
                      builder: (context, state) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: AspectRatio(
                            aspectRatio: 1.5,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  children: [
                                    CrashGraph(
                                      multiplierHistory: state.multiplierHistory,
                                      currentMultiplier: state.currentMultiplier,
                                      phase: state.phase,
                                      cashoutMultiplier: state.myBets.any((b) => b.isCashedOut)
                                          ? state.myBets.firstWhere((b) => b.isCashedOut).cashoutMultiplier
                                          : null,
                                      cashoutProfit: state.myBets.any((b) => b.isCashedOut)
                                          ? state.myBets.firstWhere((b) => b.isCashedOut).cashoutProfit
                                          : null,
                                      betAmount: state.myBets.any((b) => b.isCashedOut)
                                          ? state.myBets.firstWhere((b) => b.isCashedOut).amount
                                          : null,
                                    ),
                                    // Player count badge (bottom right)
                                    if (state.onlinePlayerCount > 0)
                                      Positioned(
                                        bottom: 10,
                                        right: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.card.withOpacity(0.8),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: AppTheme.border.withOpacity(0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text('🌐', style: TextStyle(fontSize: 12)),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${state.onlinePlayerCount}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),

                    // ─── Bet Panel (two cards) ───
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: const BetPanel(),
                    ),
                    const SizedBox(height: 8),

                    // ─── Bet Leaderboard ───
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: const BetLeaderboard(),
                    ),
                    const SizedBox(height: 16),

                    // ─── Provably Fair Footer ───
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.verified, size: 14, color: AppTheme.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                'Provably Fair Game',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'CasinoR',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // Aviator-style brand logo
          Text(
            'Aviator',
            style: GoogleFonts.pacifico(
              fontSize: 22,
              fontWeight: FontWeight.w400,
              color: AppTheme.lossRed,
            ),
          ),

          const Spacer(),

          // Balance display
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state is AuthAuthenticated) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.card.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${state.user.rawBalance} BDT',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.winGreen,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          const SizedBox(width: 8),

          // Hamburger menu
          GestureDetector(
            onTap: () {
              // Could open settings/menu
              context.read<GameBloc>().add(GameDisconnectRequested());
              context.read<AuthBloc>().add(AuthLogoutRequested());
            },
            child: const Icon(Icons.menu, size: 22, color: AppTheme.textSecondary),
          ),

          const SizedBox(width: 12),

          // Chat icon
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (context) => Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: DraggableScrollableSheet(
                    initialChildSize: 0.5,
                    minChildSize: 0.3,
                    maxChildSize: 0.9,
                    expand: false,
                    builder: (context, scrollController) {
                      return ChatPanel(scrollController: scrollController);
                    },
                  ),
                ),
              );
            },
            child: const Icon(Icons.chat_bubble_outline, size: 20, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
