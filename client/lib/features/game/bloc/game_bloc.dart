// ============================================
// Game BLoC — Core Game State Machine
// ============================================

import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crash_game/core/websocket/ws_client.dart';
import 'package:crash_game/core/websocket/ws_message.dart';
import 'package:crash_game/core/utils/error_handler.dart';

// ─── Game Phase Enum ───

enum GamePhase { connecting, waitingForRound, betting, running, crashed, cashedOut, disconnected }

// ─── Events ───

abstract class GameEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class GameConnectRequested extends GameEvent {
  final String token;
  GameConnectRequested(this.token);
}

class GameDisconnectRequested extends GameEvent {}

class GameWsMessageReceived extends GameEvent {
  final WsMessage message;
  GameWsMessageReceived(this.message);
  @override
  List<Object?> get props => [message.type];
}

class GameConnectionStateChanged extends GameEvent {
  final WsConnectionState state;
  GameConnectionStateChanged(this.state);
}

class GamePlaceBet extends GameEvent {
  final int amount;
  final int panelId;
  final double? autoCashout;
  final String? clientSeed;
  GamePlaceBet({required this.amount, required this.panelId, this.autoCashout, this.clientSeed});
}

class GameCashout extends GameEvent {
  final String betId;
  GameCashout(this.betId);
}

// Event to signal a specific panel's bet was rejected
class GameBetError extends GameEvent {
  final int panelId;
  final String message;
  GameBetError({required this.panelId, required this.message});
}

class MyBetState extends Equatable {
  final String betId;
  final int amount;
  final int panelId;
  final double? autoCashout;
  final bool isCashedOut;
  final double? cashoutMultiplier;
  final int? cashoutProfit;

  const MyBetState({
    required this.betId,
    required this.amount,
    required this.panelId,
    this.autoCashout,
    this.isCashedOut = false,
    this.cashoutMultiplier,
    this.cashoutProfit,
  });

  MyBetState copyWith({
    bool? isCashedOut,
    double? cashoutMultiplier,
    int? cashoutProfit,
  }) {
    return MyBetState(
      betId: betId,
      amount: amount,
      panelId: panelId,
      autoCashout: autoCashout,
      isCashedOut: isCashedOut ?? this.isCashedOut,
      cashoutMultiplier: cashoutMultiplier ?? this.cashoutMultiplier,
      cashoutProfit: cashoutProfit ?? this.cashoutProfit,
    );
  }

  @override
  List<Object?> get props => [betId, amount, panelId, isCashedOut, cashoutMultiplier, cashoutProfit];
}

// ─── State ───

class GameState extends Equatable {
  final GamePhase phase;
  final String roundId;
  final String serverSeedHash;
  final double currentMultiplier;
  final int elapsedMs;
  final double crashPoint;
  final int countdownMs;
  final List<double> multiplierHistory;
  final List<Map<String, dynamic>> activeBets;
  final List<Map<String, dynamic>> previousRoundBets;
  final List<Map<String, dynamic>> topWins;
  final List<MyBetState> myBets;
  final List<double> recentCrashPoints;
  final int onlinePlayerCount;
  final String? errorMessage;

  const GameState({
    this.phase = GamePhase.connecting,
    this.roundId = '',
    this.serverSeedHash = '',
    this.currentMultiplier = 1.0,
    this.elapsedMs = 0,
    this.crashPoint = 0,
    this.countdownMs = 0,
    this.multiplierHistory = const [],
    this.activeBets = const [],
    this.previousRoundBets = const [],
    this.topWins = const [],
    this.myBets = const [],
    this.recentCrashPoints = const [],
    this.onlinePlayerCount = 0,
    this.errorMessage,
  });

  GameState copyWith({
    GamePhase? phase,
    String? roundId,
    String? serverSeedHash,
    double? currentMultiplier,
    int? elapsedMs,
    double? crashPoint,
    int? countdownMs,
    List<double>? multiplierHistory,
    List<Map<String, dynamic>>? activeBets,
    List<Map<String, dynamic>>? previousRoundBets,
    List<Map<String, dynamic>>? topWins,
    List<MyBetState>? myBets,
    List<double>? recentCrashPoints,
    int? onlinePlayerCount,
    String? errorMessage,
  }) {
    return GameState(
      phase: phase ?? this.phase,
      roundId: roundId ?? this.roundId,
      serverSeedHash: serverSeedHash ?? this.serverSeedHash,
      currentMultiplier: currentMultiplier ?? this.currentMultiplier,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      crashPoint: crashPoint ?? this.crashPoint,
      countdownMs: countdownMs ?? this.countdownMs,
      multiplierHistory: multiplierHistory ?? this.multiplierHistory,
      activeBets: activeBets ?? this.activeBets,
      previousRoundBets: previousRoundBets ?? this.previousRoundBets,
      topWins: topWins ?? this.topWins,
      myBets: myBets ?? this.myBets,
      recentCrashPoints: recentCrashPoints ?? this.recentCrashPoints,
      onlinePlayerCount: onlinePlayerCount ?? this.onlinePlayerCount,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    phase, roundId, currentMultiplier, elapsedMs,
    crashPoint, countdownMs, myBets,
    multiplierHistory.length, activeBets.length,
    previousRoundBets.length, topWins.length,
    recentCrashPoints.length, onlinePlayerCount, errorMessage,
  ];
}

// ─── BLoC ───

class GameBloc extends Bloc<GameEvent, GameState> {
  final WsClient _wsClient = WsClient();
  StreamSubscription<WsMessage>? _messageSubscription;
  StreamSubscription<WsConnectionState>? _connectionSubscription;

  /// Callback for balance updates from the game server.
  /// Set this from the parent widget to forward to AuthBloc.
  void Function(int newBalance)? onBalanceUpdate;

  GameBloc() : super(const GameState()) {
    on<GameConnectRequested>(_onConnect);
    on<GameDisconnectRequested>(_onDisconnect);
    on<GameWsMessageReceived>(_onMessageReceived);
    on<GameConnectionStateChanged>(_onConnectionChanged);
    on<GamePlaceBet>(_onPlaceBet);
    on<GameCashout>(_onCashout);
    on<GameBetError>(_onBetError);
  }

  Future<void> _onConnect(GameConnectRequested event, Emitter<GameState> emit) async {
    // Subscribe to WS streams
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();

    _messageSubscription = _wsClient.messageStream.listen((msg) {
      add(GameWsMessageReceived(msg));
    });

    _connectionSubscription = _wsClient.connectionStateStream.listen((state) {
      add(GameConnectionStateChanged(state));
    });

    emit(state.copyWith(phase: GamePhase.connecting));
    await _wsClient.connect(event.token);
  }

  void _onDisconnect(GameDisconnectRequested event, Emitter<GameState> emit) {
    _wsClient.disconnect();
    emit(state.copyWith(phase: GamePhase.disconnected));
  }

  void _onConnectionChanged(GameConnectionStateChanged event, Emitter<GameState> emit) {
    switch (event.state) {
      case WsConnectionState.connected:
        emit(state.copyWith(phase: GamePhase.waitingForRound));
        break;
      case WsConnectionState.disconnected:
      case WsConnectionState.reconnecting:
        if (state.phase != GamePhase.connecting) {
          ErrorHandler.showError('Connection lost. Reconnecting...');
          emit(state.copyWith(phase: GamePhase.disconnected));
        }
        break;
      case WsConnectionState.connecting:
        emit(state.copyWith(phase: GamePhase.connecting));
        break;
    }
  }

  void _onMessageReceived(GameWsMessageReceived event, Emitter<GameState> emit) {
    final msg = event.message;

    switch (msg.type) {
      case 'ROUND_START':
        // Save current round's bets as previous round data before resetting
        final prevBets = state.activeBets.isNotEmpty
            ? List<Map<String, dynamic>>.from(state.activeBets)
            : state.previousRoundBets;
        emit(state.copyWith(
          phase: GamePhase.betting,
          roundId: msg.data['round_id'] ?? '',
          serverSeedHash: msg.data['server_seed_hash'] ?? '',
          countdownMs: msg.data['countdown_ms'] ?? 7000,
          currentMultiplier: 1.0,
          elapsedMs: 0,
          crashPoint: 0,
          multiplierHistory: [],
          activeBets: [],
          previousRoundBets: prevBets,
          myBets: [],
          errorMessage: null,
        ));
        break;

      case 'TICK':
        final multiplier = (msg.data['multiplier'] as num).toDouble();
        final elapsed = (msg.data['elapsed_ms'] as num).toInt();
        final history = [...state.multiplierHistory, multiplier];

        emit(state.copyWith(
          phase: state.phase == GamePhase.cashedOut
              ? GamePhase.cashedOut
              : GamePhase.running,
          currentMultiplier: multiplier,
          elapsedMs: elapsed,
          multiplierHistory: history,
        ));
        break;

      case 'CRASH':
        final crashPt = (msg.data['crash_point'] as num).toDouble();
        final updatedHistory = [...state.recentCrashPoints, crashPt];
        if (updatedHistory.length > 20) {
          updatedHistory.removeAt(0);
        }

        emit(state.copyWith(
          phase: GamePhase.crashed,
          crashPoint: crashPt,
          currentMultiplier: crashPt,
          recentCrashPoints: updatedHistory,
        ));

        // After 3 seconds, transition back to waiting
        Future.delayed(const Duration(seconds: 3), () {
          if (!isClosed && state.phase == GamePhase.crashed) {
            emit(state.copyWith(phase: GamePhase.waitingForRound));
          }
        });
        break;

      case 'BET_CONFIRMED':
        final betId = msg.data['betId'] as String?;
        final amount = (msg.data['amount'] as num?)?.toInt() ?? 0;
        final panelId = (msg.data['panel_id'] as num?)?.toInt() ?? 0;
        final autoCashout = (msg.data['auto_cashout'] as num?)?.toDouble();
        
        if (betId != null) {
          final newBet = MyBetState(
            betId: betId,
            amount: amount,
            panelId: panelId,
            autoCashout: autoCashout,
          );
          emit(state.copyWith(myBets: [...state.myBets, newBet]));
        }
        break;

      case 'BET_ERROR':
        final errorMsg = msg.data['message'] as String? ?? 'Bet failed';
        final panelId = (msg.data['panel_id'] as num?)?.toInt() ?? -1;
        ErrorHandler.showError(errorMsg);
        // Fire a separate event so panels can listen and reset
        add(GameBetError(panelId: panelId, message: errorMsg));
        emit(state.copyWith(errorMessage: errorMsg));
        break;

      case 'CASHOUT_CONFIRMED':
        final betId = msg.data['betId'] as String?;
        final multiplier = (msg.data['multiplier'] as num?)?.toDouble() ?? 0;
        final profit = (msg.data['profit'] as num?)?.toInt() ?? 0;

        // Fallback: if betId is null (e.g., auto-cashout from older server code), match the first active bet
        String? targetBetId = betId;
        if (targetBetId == null) {
          final uncashed = state.myBets.where((b) => !b.isCashedOut).toList();
          if (uncashed.isNotEmpty) {
            targetBetId = uncashed.first.betId;
          }
        }

        if (targetBetId != null) {
          final updatedBets = state.myBets.map((b) {
            if (b.betId == targetBetId) {
              return b.copyWith(
                isCashedOut: true,
                cashoutMultiplier: multiplier,
                cashoutProfit: profit,
              );
            }
            return b;
          }).toList();

          final allCashedOut = updatedBets.isNotEmpty && updatedBets.every((b) => b.isCashedOut);

          emit(state.copyWith(
            phase: allCashedOut ? GamePhase.cashedOut : state.phase,
            myBets: updatedBets,
          ));
        }
        break;

      case 'CASHOUT_ERROR':
        final errorMsg = msg.data['message'] as String? ?? 'Cashout failed';
        ErrorHandler.showError(errorMsg);
        emit(state.copyWith(errorMessage: errorMsg));
        break;

      case 'PLAYERS_UPDATE':
      case 'PLAYER_CASHOUT':
        // Refresh active bets list
        final bets = msg.data['bets'] as List<dynamic>?;
        final playerCount = (msg.data['playerCount'] as num?)?.toInt();
        if (bets != null) {
          final betsList = bets.cast<Map<String, dynamic>>();
          // Update top wins: track highest individual wins across the session
          final newTopWins = List<Map<String, dynamic>>.from(state.topWins);
          for (final bet in betsList) {
            if (bet['status'] == 'cashed_out' && bet['profit'] != null) {
              final winAmount = (bet['amount'] as num).toInt() + (bet['profit'] as num).toInt();
              final entry = {
                'username': bet['username'],
                'amount': bet['amount'],
                'cashoutMultiplier': bet['cashoutMultiplier'],
                'profit': bet['profit'],
                'winAmount': winAmount,
              };
              // Add if not already tracked (simple dedup by username+amount combo)
              final isDuplicate = newTopWins.any((t) =>
                t['username'] == bet['username'] &&
                t['amount'] == bet['amount'] &&
                t['cashoutMultiplier'] == bet['cashoutMultiplier']);
              if (!isDuplicate) {
                newTopWins.add(entry);
              }
            }
          }
          // Sort by win amount descending, keep top 20
          newTopWins.sort((a, b) =>
            ((b['winAmount'] as num?) ?? 0).compareTo((a['winAmount'] as num?) ?? 0));
          if (newTopWins.length > 20) {
            newTopWins.removeRange(20, newTopWins.length);
          }

          emit(state.copyWith(
            activeBets: betsList,
            topWins: newTopWins,
            onlinePlayerCount: playerCount ?? state.onlinePlayerCount,
          ));
        }
        break;

      case 'GAME_STATE':
        // Full state sync on reconnect
        final phase = msg.data['phase'] as String?;
        GamePhase gamePhase = GamePhase.waitingForRound;
        if (phase == 'BETTING') gamePhase = GamePhase.betting;
        if (phase == 'RUNNING') gamePhase = GamePhase.running;
        if (phase == 'CRASHED') gamePhase = GamePhase.crashed;

        emit(state.copyWith(
          phase: gamePhase,
          roundId: msg.data['roundId'] ?? '',
          serverSeedHash: msg.data['serverSeedHash'] ?? '',
          currentMultiplier: (msg.data['multiplier'] as num?)?.toDouble() ?? 1.0,
          elapsedMs: (msg.data['elapsedMs'] as num?)?.toInt() ?? 0,
        ));
        break;

      case 'BALANCE_UPDATE':
        // Forward balance update to AuthBloc via callback
        final balance = msg.data['balance'] as int?;
        if (balance != null && onBalanceUpdate != null) {
          onBalanceUpdate!(balance);
        }
        break;

      default:
        break;
    }
  }

  void _onPlaceBet(GamePlaceBet event, Emitter<GameState> emit) {
    _wsClient.send(WsMessage.bet(
      amount: event.amount,
      panelId: event.panelId,
      autoCashout: event.autoCashout,
      clientSeed: event.clientSeed,
    ));
  }

  void _onCashout(GameCashout event, Emitter<GameState> emit) {
    if (state.phase == GamePhase.running) {
      _wsClient.send(WsMessage.cashout(event.betId));
    }
  }

  void _onBetError(GameBetError event, Emitter<GameState> emit) {
    // This event is handled by the bet panels via BlocListener
    // No state change needed here — each panel resets its own _isPendingPlacement
  }

  @override
  Future<void> close() {
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    return super.close();
  }
}
