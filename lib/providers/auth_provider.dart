import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/auth_repository.dart';
import '../models/business_affiliation.dart';
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
    this.pendingAffiliations,
  });

  final AuthStatus status;
  final User? user;
  final CleanerProfile? profile;
  final String? error;
  final bool isLoading;

  /// Non-null only while the login flow is paused waiting for the user to
  /// pick which business to sign into (see [BusinessSelectionRequiredException]).
  final List<BusinessAffiliation>? pendingAffiliations;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isCleanerActive => profile?.isActive == true;
  bool get needsBusinessSelection => pendingAffiliations != null;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    CleanerProfile? profile,
    String? error,
    bool? isLoading,
    bool clearError = false,
    List<BusinessAffiliation>? pendingAffiliations,
    bool clearPendingAffiliations = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      profile: profile ?? this.profile,
      error: clearError ? null : (error ?? this.error),
      isLoading: isLoading ?? this.isLoading,
      pendingAffiliations: clearPendingAffiliations
          ? null
          : (pendingAffiliations ?? this.pendingAffiliations),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo) : super(const AuthState()) {
    _bootstrap();
  }

  final AuthRepository _repo;

  // Held only in memory, only for the lifetime of an in-progress "pick a
  // business" step, and cleared as soon as it resolves either way. Never
  // written to storage.
  String? _pendingEmail;
  String? _pendingPassword;

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
    state = state.copyWith(isLoading: true, clearError: true, clearPendingAffiliations: true);
    try {
      final result = await _repo.login(email: email, password: password);
      return _applyLoginResult(result);
    } on BusinessSelectionRequiredException catch (e) {
      // Correct credentials — just ambiguous which business. Hold the
      // credentials in memory only (never persisted) so selectBusiness()
      // below can re-submit login with the chosen businessId without
      // asking the cleaner to type their password again.
      _pendingEmail = email;
      _pendingPassword = password;
      state = state.copyWith(isLoading: false, pendingAffiliations: e.affiliations);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        status: AuthStatus.unauthenticated,
        error: _mapError(e),
      );
      return false;
    }
  }

  /// Completes a login that was paused by [BusinessSelectionRequiredException]
  /// once the cleaner has picked which business to sign into.
  Future<bool> selectBusiness(String businessId) async {
    final email = _pendingEmail;
    final password = _pendingPassword;
    if (email == null || password == null) {
      // Shouldn't happen from the UI (the picker only shows while
      // pendingAffiliations is set, which implies these were just set too),
      // but fail safely back to a plain login screen rather than crash.
      state = state.copyWith(
        clearPendingAffiliations: true,
        error: 'Session expired — please sign in again.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _repo.login(
        email: email,
        password: password,
        businessId: businessId,
      );
      _pendingEmail = null;
      _pendingPassword = null;
      return _applyLoginResult(result);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _mapError(e));
      return false;
    }
  }

  /// Discards an in-progress business-selection step (e.g. the cleaner
  /// backs out of the picker) so the login screen shows its normal form
  /// again instead of being stuck.
  void cancelBusinessSelection() {
    _pendingEmail = null;
    _pendingPassword = null;
    state = state.copyWith(clearPendingAffiliations: true);
  }

  /// Switches to a different business mid-session — for a cleaner who works
  /// for more than one, from the "switch business" picker (see
  /// business_switcher_sheet.dart), not the login-time one above. No
  /// password needed: this reuses the still-valid access token to call
  /// POST /auth/select-business, which re-issues tokens scoped to the new
  /// business.
  ///
  /// Every screen that reads today's/upcoming jobs watches [authProvider]
  /// itself, so replacing [state] below already refreshes those. Messaging,
  /// profile, availability, documents, and earnings providers don't watch
  /// [authProvider] — the caller (business_switcher_sheet.dart) is
  /// responsible for invalidating those on success, so this notifier
  /// doesn't need to import every feature's providers just to switch a
  /// business.
  Future<bool> switchBusiness(String businessId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _repo.switchBusiness(businessId);
      return _applyLoginResult(result);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _mapError(e));
      return false;
    }
  }

  bool _applyLoginResult(
    ({User user, CleanerProfile? profile, String access, String refresh}) result,
  ) {
    if (result.profile == null || !result.profile!.isActive) {
      unawaited(_repo.logout());
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

/// Every workspace the signed-in account can switch into — feeds the
/// "switch business" picker. Re-fetch with `ref.invalidate` after a switch
/// succeeds so a business the account just lost access to (e.g. offboarded
/// mid-session elsewhere) drops out of the list next time it's opened.
final affiliationsProvider =
    FutureProvider.autoDispose<List<BusinessAffiliation>>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.fetchAffiliations();
});
