// ============================================
// WebSocket Client — Connection Manager
// ============================================

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:crash_game/config/app_config.dart';
import 'package:crash_game/core/websocket/ws_message.dart';

enum WsConnectionState { disconnected, connecting, connected, reconnecting }

class WsClient {
  static final WsClient _instance = WsClient._internal();
  factory WsClient() => _instance;
  WsClient._internal();

  WebSocketChannel? _channel;
  String? _token;

  final _messageController = StreamController<WsMessage>.broadcast();
  final _connectionStateController =
      StreamController<WsConnectionState>.broadcast();

  Stream<WsMessage> get messageStream => _messageController.stream;
  Stream<WsConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  WsConnectionState _state = WsConnectionState.disconnected;
  WsConnectionState get state => _state;

  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  bool _intentionalDisconnect = false;

  /// Connects to the WebSocket server with JWT authentication.
  Future<void> connect(String token) async {
    _token = token;
    _intentionalDisconnect = false;
    await _doConnect();
  }

  /// Sends a message through the WebSocket connection.
  void send(WsMessage message) {
    if (_state == WsConnectionState.connected && _channel != null) {
      try {
        _channel!.sink.add(jsonEncode(message.toJson()));
      } catch (e) {
        // Connection may have been lost
        _handleDisconnect();
      }
    }
  }

  /// Gracefully disconnects.
  void disconnect() {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _setState(WsConnectionState.disconnected);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _connectionStateController.close();
  }

  // ─── Private Methods ───

  Future<void> _doConnect() async {
    if (_token == null) return;

    _setState(
      _reconnectAttempts > 0
          ? WsConnectionState.reconnecting
          : WsConnectionState.connecting,
    );

    try {
      final uri = Uri.parse('${AppConfig.effectiveWsUrl}?token=$_token');
      _channel = WebSocketChannel.connect(uri);

      // Wait for the connection to be established
      await _channel!.ready;

      _reconnectAttempts = 0;
      _setState(WsConnectionState.connected);
      _startHeartbeat();

      // Listen for messages
      _channel!.stream.listen(
        (dynamic data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            final message = WsMessage.fromJson(json);
            _messageController.add(message);
          } catch (e) {
            // Invalid message — skip
          }
        },
        onDone: _handleDisconnect,
        onError: (_) => _handleDisconnect(),
      );
    } catch (e) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _heartbeatTimer?.cancel();
    _channel = null;

    if (_intentionalDisconnect) {
      _setState(WsConnectionState.disconnected);
      return;
    }

    _setState(WsConnectionState.reconnecting);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    // Exponential backoff: 1s, 2s, 4s, 8s, ... max 30s
    final delay = Duration(
      milliseconds: (AppConfig.wsReconnectBaseMs *
              (1 << _reconnectAttempts.clamp(0, 14)))
          .clamp(0, AppConfig.wsReconnectMaxMs),
    );

    _reconnectAttempts++;

    _reconnectTimer = Timer(delay, () {
      if (!_intentionalDisconnect) {
        _doConnect();
      }
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(milliseconds: AppConfig.wsHeartbeatIntervalMs),
      (_) {
        send(WsMessage.pong());
      },
    );
  }

  void _setState(WsConnectionState newState) {
    _state = newState;
    _connectionStateController.add(newState);
  }
}
