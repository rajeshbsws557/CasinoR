// ============================================
// App Configuration — Environment Settings
// ============================================

import 'package:flutter/foundation.dart';

class AppConfig {
  // Change these for production deployment (mobile/desktop native)
  // e.g., 'ws://203.0.113.50/ws' or 'wss://api.casinor.com/ws'
  static const String wsUrl = 'ws://4.240.88.100:3000/ws';
  static const String apiUrl = 'http://4.240.88.100:3001/api';

  // Dev overrides (direct to services, bypassing nginx)
  static const String wsUrlDev = 'ws://localhost:3000/ws';
  static const String apiUrlDev = 'http://localhost:3001/api';

  // Forced to false so you can test the live VPS even in debug mode
  static const bool isDev = false;

  static String get effectiveWsUrl {
    if (kIsWeb && !isDev) {
      final uri = Uri.base;
      final protocol = uri.scheme == 'https' ? 'wss' : 'ws';
      return '$protocol://${uri.host}:${uri.port}/ws';
    }
    return isDev ? wsUrlDev : wsUrl;
  }

  static String get effectiveApiUrl {
    if (kIsWeb && !isDev) {
      final uri = Uri.base;
      return '${uri.scheme}://${uri.host}:${uri.port}/api';
    }
    return isDev ? apiUrlDev : apiUrl;
  }

  // Game timing
  static const int tickIntervalMs = 50;
  static const int bettingPhaseMs = 7000;
  static const int cooldownPhaseMs = 3000;

  // WebSocket
  static const int wsReconnectBaseMs = 1000;
  static const int wsReconnectMaxMs = 30000;
  static const int wsHeartbeatIntervalMs = 15000;
  static const int wsHeartbeatTimeoutMs = 5000;
}
