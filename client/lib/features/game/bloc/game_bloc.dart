// ============================================
// Game BLoC — Core Game State Machine
// ============================================

import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crash_game/core/websocket/ws_client.dart';
import 'package:crash_game/core/websocket/ws_message.dart';

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
  final double? autoCashout;
  final String? clientSeed;
  GamePlaceBet({required this.amount, this.autoCashout, this.clientSeed});
}

class GameCashout extends GameEvent {}

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
  final double? cashoutMultiplier;
  final int? cashoutProfit;
  final List<double> recentCrashPoints;
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
    this.cashoutMultiplier,
    this.cashoutProfit,
    this.recentCrashPoints = const [],
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
    double? cashoutMultiplier,
    int? cashoutProfit,
    List<double>? recentCrashPoints,
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
      cashoutMultiplier: cashoutMultiplier ?? this.cashoutMultiplier,
      cashoutProfit: cashoutProfit ?? this.cashoutProfit,
      recentCrashPoints: recentCrashPoints ?? this.recentCrashPoints,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    phase, roundId, currentMultiplier, elapsedMs,
    crashPoint, countdownMs, cashoutMultiplier,
    multiplierHistory.length, activeBets.length,
    recentCrashPoints.length, errorMessage,
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
          cashoutMultiplier: null,
          cashoutProfit: null,
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
        // Bet was accepted — handled by UI
        break;

      case 'BET_ERROR':
        emit(state.copyWith(
          errorMessage: msg.data['message'] as String?,
        ));
        break;

      case 'CASHOUT_CONFIRMED':
        final multiplier = (msg.data['multiplier'] as num).toDouble();
        final profit = (msg.data['profit'] as num).toInt();

        emit(state.copyWith(
          phase: GamePhase.cashedOut,
          cashoutMultiplier: multiplier,
          cashoutProfit: profit,
        ));
        break;

      case 'CASHOUT_ERROR':
        emit(state.copyWith(
          errorMessage: msg.data['message'] as String?,
        ));
        break;

      case 'PLAYERS_UPDATE':
      case 'PLAYER_CASHOUT':
        // Refresh active bets list
        final bets = msg.data['bets'] as List<dynamic>?;
        if (bets != null) {
          emit(state.copyWith(
            activeBets: bets.cast<Map<String, dynamic>>(),
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
      autoCashout: event.autoCashout,
      clientSeed: event.clientSeed,
    ));
  }

  void _onCashout(GameCashout event, Emitter<GameState> emit) {
    _wsClient.send(WsMessage.cashout());
  }

  @override
  Future<void> close() {
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    return super.close();
  }
}
