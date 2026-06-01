// ============================================
// Auth Repository — API Calls
// ============================================

import 'package:crash_game/core/api/api_client.dart';
import 'package:crash_game/features/auth/models/user_model.dart';

class AuthRepository {
  final ApiClient _api = ApiClient();

  Future<({String token, UserModel user})> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _api.dio.post('/auth/register', data: {
      'username': username,
      'email': email,
      'password': password,
    });

    final data = response.data['data'];
    final token = data['token'] as String;
    final user = UserModel.fromJson(data['user']);

    await _api.setToken(token);
    return (token: token, user: user);
  }

  Future<({String token, UserModel user})> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });

    final data = response.data['data'];
    final token = data['token'] as String;
    final user = UserModel.fromJson(data['user']);

    await _api.setToken(token);
    return (token: token, user: user);
  }

  Future<UserModel?> getProfile() async {
    try {
      final token = await _api.getToken();
      if (token == null) return null;

      final response = await _api.dio.get('/auth/me');
      if (response.data['success'] == true) {
        return UserModel.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
  }

  Future<String?> getToken() => _api.getToken();
}
