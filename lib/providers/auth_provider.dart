import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/auth_repository.dart';
import '../models/cleaner_profile.dart';
import '../models/user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.profile,
    this.error,
    this.isLoading = false,
  });

  final AuthStatus status;
  final User? user;
  final CleanerProfile? profile;
  final String? error;
  final bool isLoading;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isCleanerActive => profile?.isActive == true;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    CleanerProfile? profile,
    String? error,
    bool? isLoading,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      profile: profile ?? this.profile,
      error: clearError ? null : (error ?? this.error),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo) : super(const AuthState()) {
    _bootstrap();
  }

  final AuthRepository _repo;

  Future<void> _bootstrap() async {
    final token = await _repo.getAccessToken();
    if (token == null || token.isEmpty) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    final user = await _repo.restoreUser();
    final profile = await _repo.restoreProfile();
    if (user != null) {
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        profile: profile,
      );
      // Refresh profile in background
      try {
        final fresh = await _repo.fetchCleanerMe();
        state = state.copyWith(profile: fresh);
      } catch (_) {}
      // Re-register for push on every cold start of an existing session —
      // FCM tokens rotate, so this is the standard way to keep the
      // backend's CleanerDeviceToken current without a background service.
      unawaited(_repo.registerPushToken());
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _repo.login(email: email, password: password);
      if (result.profile == null || !result.profile!.isActive) {
        await _repo.logout();
        state = const AuthState(
          status: AuthStatus.unauthenticated,
          error: 'No active cleaner profile for this account. Contact your business.',
        );
        return false;
      }
      state = AuthState(
        status: AuthStatus.authenticated,
        user: result.user,
        profile: result.profile,
      );
      unawaited(_repo.registerPushToken());
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        status: AuthStatus.unauthenticated,
        error: _mapError(e),
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Re-fetches the cleaner's own profile and updates the cached copy used
  /// by the bottom-nav Profile tab — called after a profile/avatar edit so
  /// that summary view doesn't show stale data until the next app launch.
  Future<void> refreshCleanerProfile() async {
    try {
      final fresh = await _repo.fetchCleanerMe();
      state = state.copyWith(profile: fresh);
    } catch (_) {
      // Best-effort — the dedicated profile screen already has the fresh
      // data regardless of whether this background sync succeeds.
    }
  }

  String _mapError(Object e) {
    final msg = e.toString();
    if (msg.contains('401') || msg.contains('Invalid')) {
      return 'Invalid email or password';
    }
    if (msg.contains('SocketException') || msg.contains('connection')) {
      return 'Network error. Check your connection.';
    }
    return 'Login failed. Please try again.';
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
