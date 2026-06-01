// ============================================
// WebSocket Message Models
// ============================================

// ignore_for_file: use_null_aware_elements

class WsMessage {
  final String type;
  final Map<String, dynamic> data;

  WsMessage({required this.type, required this.data});

  factory WsMessage.fromJson(Map<String, dynamic> json) {
    return WsMessage(
      type: json['type'] as String,
      data: Map<String, dynamic>.from(json['data'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {'type': type, 'data': data};

  // ─── Convenience constructors for client → server messages ───

  factory WsMessage.bet({
    required int amount,
    double? autoCashout,
    String? clientSeed,
  }) {
    return WsMessage(
      type: 'BET',
      data: {
        'amount': amount,
        if (autoCashout != null) 'auto_cashout': autoCashout,
        if (clientSeed != null) 'client_seed': clientSeed,
      },
    );
  }

  factory WsMessage.cashout(String betId) {
    return WsMessage(type: 'CASHOUT', data: {'betId': betId});
  }

  factory WsMessage.chat(String message) {
    return WsMessage(
      type: 'CHAT',
      data: {'message': message},
    );
  }

  factory WsMessage.pong() {
    return WsMessage(type: 'PONG', data: {});
  }
}
