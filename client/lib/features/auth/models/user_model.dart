// ============================================
// User Model
// ============================================

class PaymentMethod {
  final String type; // 'bkash' or 'nagad'
  final String phoneNumber;

  PaymentMethod({required this.type, required this.phoneNumber});

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      type: json['type'] as String,
      phoneNumber: json['phone_number'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'phone_number': phoneNumber,
  };
}

class UserModel {
  final String id;
  final String username;
  final String email;
  final int balance; // In paisa (1 BDT = 100 paisa)
  final int totalWagered;
  final int totalProfit;
  final String? createdAt;
  final List<PaymentMethod> paymentMethods;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.balance,
    this.totalWagered = 0,
    this.totalProfit = 0,
    this.createdAt,
    this.paymentMethods = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      balance: json['balance'] as int,
      totalWagered: json['totalWagered'] as int? ?? json['total_wagered'] as int? ?? 0,
      totalProfit: json['totalProfit'] as int? ?? json['total_profit'] as int? ?? 0,
      createdAt: json['createdAt'] as String? ?? json['created_at']?.toString(),
      paymentMethods: (json['paymentMethods'] as List<dynamic>?)
          ?.map((m) => PaymentMethod.fromJson(m as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  /// Formatted balance with BDT taka symbol
  String get formattedBalance => '৳${(balance / 100).toStringAsFixed(2)}';

  /// Short formatted balance (no decimal if round number)
  String get shortBalance {
    final bdt = balance / 100;
    return bdt == bdt.roundToDouble()
        ? '৳${bdt.toInt()}'
        : '৳${bdt.toStringAsFixed(2)}';
  }

  /// Raw BDT value (for display without symbol)
  String get rawBalance => (balance / 100).toStringAsFixed(2);

  /// Formatted total wagered in taka
  String get formattedWagered => '৳${(totalWagered / 100).toStringAsFixed(2)}';

  /// Formatted total profit in taka
  String get formattedProfit {
    final bdt = totalProfit / 100;
    final prefix = bdt >= 0 ? '+' : '';
    return '$prefix৳${bdt.toStringAsFixed(2)}';
  }

  UserModel copyWith({
    int? balance,
    String? username,
    List<PaymentMethod>? paymentMethods,
  }) {
    return UserModel(
      id: id,
      username: username ?? this.username,
      email: email,
      balance: balance ?? this.balance,
      totalWagered: totalWagered,
      totalProfit: totalProfit,
      createdAt: createdAt,
      paymentMethods: paymentMethods ?? this.paymentMethods,
    );
  }
}
