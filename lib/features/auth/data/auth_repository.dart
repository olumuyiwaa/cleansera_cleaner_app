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

    return _applySession(data);
  }

  /// Lists the businesses this account can switch into as a cleaner.
  /// Backing data for the in-app "switch business" picker; the login-time
  /// picker uses the affiliations bundled in
  /// [BusinessSelectionRequiredException] instead, since at that point
  /// there's no access token yet to call this with.
  ///
  /// The backend's affiliations list also includes businesses where this
  /// account is *staff* (a BusinessMember) rather than a cleaner — this app
  /// has no screens for that role, and switching into one would trip
  /// [_applyLoginResult]'s "no active cleaner profile" guard and sign the
  /// person out entirely. Filtered out here so a staff-only business can
  /// never even appear as an option.
  Future<List<BusinessAffiliation>> fetchAffiliations() async {
    final res = await _dio.get(ApiConstants.affiliations);
    return unwrapListEnvelope(res.data)
        .map((a) => BusinessAffiliation.fromJson(a as Map<String, dynamic>))
        .where((a) => a.role == 'CLEANER')
        .toList();
  }

  /// Switches the active workspace for an already-authenticated user — the
  /// mid-session equivalent of picking a business during login, but without
  /// asking for the password again. Overwrites the stored session in place,
  /// same as [login]; the new tokens are scoped to [businessId] from this
  /// point on, so every subsequent request lands in that business's data.
  Future<({User user, CleanerProfile? profile, String access, String refresh})>
      switchBusiness(String businessId) async {
    final res = await _dio.post(
      ApiConstants.selectBusiness,
      data: {'businessId': businessId},
    );
    final data = unwrapEnvelope(res.data);
    return _applySession(data);
  }

  /// Shared by [login] and [switchBusiness] — both endpoints return the same
  /// `{ accessToken, refreshToken, user, cleanerProfile }` shape (see
  /// issueSession in cleansera_sass/src/modules/auth/auth.service.js), and
  /// both need it persisted to storage the same way.
  Future<({User user, CleanerProfile? profile, String access, String refresh})>
      _applySession(Map<String, dynamic> data) async {
    final access = data['accessToken'] as String;
    final refresh = data['refreshToken'] as String;

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
      // Not every workspace is one this account cleans for (it might only be
      // staff there) — absence here just means no active cleaner profile in
      // the just-selected business, which the caller handles.
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
    // Overwrite unconditionally — including clearing a stale profile from
    // the previous business when the newly-selected one has none, so the
    // cached copy never leaks across a switch.
    if (profile != null) {
      await _storage.write(
        key: AppConstants.storageCleanerProfile,
        value: jsonEncode(profile.toJson()),
      );
    } else {
      await _storage.delete(key: AppConstants.storageCleanerProfile);
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
