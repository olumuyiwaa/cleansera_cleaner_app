import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/push_service.dart';
import '../../../models/business_affiliation.dart';
import '../../../models/cleaner_profile.dart';
import '../../../models/user.dart';

class AuthRepository {
  AuthRepository(this._dio, this._storage);

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<({User user, CleanerProfile? profile, String access, String refresh})>
      login({
    required String email,
    required String password,
    String? businessId,
  }) async {
    final res = await _dio.post(
      ApiConstants.login,
      data: {
        'email': email,
        'password': password,
        if (businessId != null) 'businessId': businessId,
      },
    );
    // Every backend response is wrapped as { success, message, data }.
    final data = unwrapEnvelope(res.data);

    // Correct credentials, but this account is affiliated with more than
    // one business (staff and/or cleaner at several businesses) — the
    // backend deliberately issues no tokens here (see auth.service.js
    // login()) and expects the client to re-submit this same call with a
    // chosen `businessId`. No accessToken key is present in this response.
    if (data['requiresBusinessSelection'] == true) {
      final affiliations = (data['affiliations'] as List<dynamic>? ?? [])
          .map((a) => BusinessAffiliation.fromJson(a as Map<String, dynamic>))
          .toList();
      throw BusinessSelectionRequiredException(affiliations);
    }

    final access = data['accessToken'] as String;
    final refresh = data['refreshToken'] as String;

    // Login now returns `user` (and, for a cleaner account, `cleanerProfile`)
    // directly — no separate round-trip needed for the common case. Still
    // fall back to a dedicated fetch if either is ever missing, so an older
    // backend build doesn't break the app outright.
    User user;
    if (data['user'] is Map<String, dynamic>) {
      user = User.fromJson(data['user'] as Map<String, dynamic>);
    } else {
      final me = await _dio.get(
        ApiConstants.me,
        options: Options(headers: {'Authorization': 'Bearer $access'}),
      );
      user = User.fromJson(unwrapEnvelope(me.data));
    }

    CleanerProfile? profile;
    if (data['cleanerProfile'] is Map<String, dynamic>) {
      profile = CleanerProfile.fromJson(
          data['cleanerProfile'] as Map<String, dynamic>);
    } else {
      // Not every login is a cleaner (or the backend didn't include it) —
      // fetch the dedicated cleaner profile; absence here just means this
      // account isn't an active cleaner anywhere, which the caller handles.
      try {
        final me = await _dio.get(
          ApiConstants.cleanerMe,
          options: Options(headers: {'Authorization': 'Bearer $access'}),
        );
        profile = CleanerProfile.fromJson(unwrapEnvelope(me.data));
      } catch (_) {
        profile = null;
      }
    }

    await _storage.write(key: AppConstants.storageAccessToken, value: access);
    await _storage.write(key: AppConstants.storageRefreshToken, value: refresh);
    await _storage.write(
        key: AppConstants.storageUser, value: jsonEncode(user.toJson()));
    if (profile != null) {
      await _storage.write(
        key: AppConstants.storageCleanerProfile,
        value: jsonEncode(profile.toJson()),
      );
    }

    return (user: user, profile: profile, access: access, refresh: refresh);
  }

  Future<void> logout() async {
    // Best-effort: stop this device's push notifications before the token
    // used to authorize the unregister call is cleared below.
    await PushService.instance.unregisterToken(_dio);
    try {
      // The backend requires `refreshToken` in the body (see
      // cleansera_sass/src/modules/auth/auth.routes.js — it 400s without
      // it) and deletes the matching Session row so the token can't be
      // used again. Posting with no body silently failed validation here,
      // so the server-side session was never actually revoked and a
      // copied/stolen refresh token kept working after "logout".
      final refresh = await _storage.read(key: AppConstants.storageRefreshToken);
      if (refresh != null) {
        await _dio.post(ApiConstants.logout, data: {'refreshToken': refresh});
      }
    } catch (_) {}
    await _storage.deleteAll();
  }

  /// Registers this device for push notifications. Called after a
  /// successful login and once at app bootstrap for an already-authenticated
  /// session (see AuthNotifier). Never throws — push is a nice-to-have, not
  /// a login-blocking dependency.
  Future<void> registerPushToken() => PushService.instance.registerToken(_dio);

  Future<User?> restoreUser() async {
    final raw = await _storage.read(key: AppConstants.storageUser);
    if (raw == null) return null;
    try {
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<CleanerProfile?> restoreProfile() async {
    final raw = await _storage.read(key: AppConstants.storageCleanerProfile);
    if (raw == null) return null;
    try {
      return CleanerProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getAccessToken() =>
      _storage.read(key: AppConstants.storageAccessToken);

  Future<CleanerProfile> fetchCleanerMe() async {
    final res = await _dio.get(ApiConstants.cleanerMe);
    final profile = CleanerProfile.fromJson(unwrapEnvelope(res.data));
    await _storage.write(
      key: AppConstants.storageCleanerProfile,
      value: jsonEncode(profile.toJson()),
    );
    return profile;
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider), const FlutterSecureStorage());
});
