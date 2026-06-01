// ============================================
// Auth BLoC — Authentication State Management
// ============================================

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crash_game/features/auth/models/user_model.dart';
import 'package:crash_game/features/auth/repositories/auth_repository.dart';

// ─── Events ───

abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  AuthLoginRequested({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

class AuthRegisterRequested extends AuthEvent {
  final String username;
  final String email;
  final String password;
  AuthRegisterRequested({
    required this.username,
    required this.email,
    required this.password,
  });
  @override
  List<Object?> get props => [username, email, password];
}

class AuthLogoutRequested extends AuthEvent {}

class AuthBalanceUpdated extends AuthEvent {
  final int newBalance;
  AuthBalanceUpdated(this.newBalance);
  @override
  List<Object?> get props => [newBalance];
}

// ─── States ───

abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final UserModel user;
  final String token;
  AuthAuthenticated({required this.user, required this.token});
  @override
  List<Object?> get props => [user, token];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepo;

  AuthBloc({AuthRepository? authRepository})
      : _authRepo = authRepository ?? AuthRepository(),
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthBalanceUpdated>(_onBalanceUpdated);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final token = await _authRepo.getToken();
    if (token == null) {
      emit(AuthUnauthenticated());
      return;
    }

    final user = await _authRepo.getProfile();
    if (user != null) {
      emit(AuthAuthenticated(user: user, token: token));
    } else {
      await _authRepo.logout();
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await _authRepo.login(
        email: event.email,
        password: event.password,
      );
      emit(AuthAuthenticated(user: result.user, token: result.token));
    } catch (e) {
      final message = _extractErrorMessage(e);
      emit(AuthError(message));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await _authRepo.register(
        username: event.username,
        email: event.email,
        password: event.password,
      );
      emit(AuthAuthenticated(user: result.user, token: result.token));
    } catch (e) {
      final message = _extractErrorMessage(e);
      emit(AuthError(message));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepo.logout();
    emit(AuthUnauthenticated());
  }

  void _onBalanceUpdated(
    AuthBalanceUpdated event,
    Emitter<AuthState> emit,
  ) {
    if (state is AuthAuthenticated) {
      final current = state as AuthAuthenticated;
      emit(AuthAuthenticated(
        user: current.user.copyWith(balance: event.newBalance),
        token: current.token,
      ));
    }
  }

  String _extractErrorMessage(dynamic e) {
    try {
      if (e is Exception && e.toString().contains('DioException')) {
        final dioError = e as dynamic;
        return dioError.response?.data?['error'] ?? 'Network error occurred';
      }
    } catch (_) {}
    return 'An unexpected error occurred';
  }
}
