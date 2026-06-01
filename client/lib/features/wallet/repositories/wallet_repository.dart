// ============================================
// Wallet Repository — API Calls for Deposits & Withdrawals
// ============================================

import 'package:crash_game/core/api/api_client.dart';

class WalletRepository {
  final ApiClient _api = ApiClient();

  // ─── Balance ───

  Future<Map<String, dynamic>> getBalance() async {
    final response = await _api.dio.get('/wallet/balance');
    return response.data['data'] as Map<String, dynamic>;
  }

  // ─── Transactions ───

  Future<Map<String, dynamic>> getTransactions({int page = 1, int limit = 20}) async {
    final response = await _api.dio.get('/wallet/transactions', queryParameters: {
      'page': page,
      'limit': limit,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  // ─── Deposit ───

  /// Returns deposit info: payment number, methods, limits, instructions
  Future<Map<String, dynamic>> getDepositInfo() async {
    final response = await _api.dio.get('/wallet/deposit-info');
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Submits a deposit request with bKash/Nagad transaction ID
  Future<Map<String, dynamic>> submitDeposit({
    required String method,
    required String transactionId,
    required int amount,
  }) async {
    final response = await _api.dio.post('/wallet/deposit', data: {
      'method': method,
      'transaction_id': transactionId,
      'amount': amount,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Returns the user's deposit history
  Future<Map<String, dynamic>> getDeposits({int page = 1, int limit = 20}) async {
    final response = await _api.dio.get('/wallet/deposits', queryParameters: {
      'page': page,
      'limit': limit,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  // ─── Withdrawal ───

  /// Submits a withdrawal request
  Future<Map<String, dynamic>> submitWithdrawal({
    required String method,
    required String phoneNumber,
    required int amount,
  }) async {
    final response = await _api.dio.post('/wallet/withdraw', data: {
      'method': method,
      'phone_number': phoneNumber,
      'amount': amount,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Returns the user's withdrawal history
  Future<Map<String, dynamic>> getWithdrawals({int page = 1, int limit = 20}) async {
    final response = await _api.dio.get('/wallet/withdrawals', queryParameters: {
      'page': page,
      'limit': limit,
    });
    return response.data['data'] as Map<String, dynamic>;
  }
}
