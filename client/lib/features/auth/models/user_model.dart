// ============================================
// User Model
// ============================================

class UserModel {
  final String id;
  final String username;
  final String email;
  final int balance; // In paisa (1 BDT = 100 paisa)

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.balance,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      balance: json['balance'] as int,
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

  UserModel copyWith({int? balance}) {
    return UserModel(
      id: id,
      username: username,
      email: email,
      balance: balance ?? this.balance,
    );
  }
}
