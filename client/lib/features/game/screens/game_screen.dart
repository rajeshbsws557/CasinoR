// ============================================
// Game Screen — Main Gameplay UI
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
import 'package:crash_game/features/chat/widgets/chat_panel.dart';
import 'package:crash_game/features/game/widgets/animated_space_background.dart';
import 'package:crash_game/core/widgets/glass_container.dart';

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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
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
        backgroundColor: AppTheme.accentPurple,
        child: const Icon(Icons.chat_bubble_outline),
      ),
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

            // ─── Crash Graph (main visual) ───
            Expanded(
              flex: 5,
              child: BlocBuilder<GameBloc, GameState>(
                builder: (context, state) {
                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CrashGraph(
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
                      ),
                    ),
                  );
                },
              ),
            ),

            // ─── Game History Bar ───
            BlocBuilder<GameBloc, GameState>(
              buildWhen: (prev, curr) =>
                  prev.recentCrashPoints.length != curr.recentCrashPoints.length,
              builder: (context, state) {
                return GameHistoryBar(crashPoints: state.recentCrashPoints);
              },
            ),
            const SizedBox(height: 8),

            // ─── Bet Panel ───
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SingleChildScrollView(
                  child: const BetPanel(),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Logo
          ShaderMask(
            shaderCallback: (bounds) =>
                AppTheme.accentGradient.createShader(bounds),
            child: Text(
              '🚀 CRASH',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),

          const Spacer(),

          // Balance
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state is AuthAuthenticated) {
                return GlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  borderRadius: BorderRadius.circular(20),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet,
                          size: 14, color: AppTheme.winGreen),
                      const SizedBox(width: 6),
                      Text(
                        state.user.formattedBalance,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          const SizedBox(width: 8),

          // Logout
          IconButton(
            icon: const Icon(Icons.logout, size: 20, color: AppTheme.textSecondary),
            onPressed: () {
              context.read<GameBloc>().add(GameDisconnectRequested());
              context.read<AuthBloc>().add(AuthLogoutRequested());
            },
          ),
        ],
      ),
    );
  }
}
