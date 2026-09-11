import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
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
  }) async {
    final res = await _dio.post(
      ApiConstants.login,
      data: {'email': email, 'password': password},
    );
    final data = res.data as Map<String, dynamic>;
    final access = data['accessToken'] as String;
    final refresh = data['refreshToken'] as String;
    final user = User.fromJson(data['user'] as Map<String, dynamic>);

    CleanerProfile? profile;
    if (data['cleanerProfile'] is Map<String, dynamic>) {
      profile =
          CleanerProfile.fromJson(data['cleanerProfile'] as Map<String, dynamic>);
    } else {
      // Fetch dedicated cleaner profile after login
      try {
        final me = await _dio.get(
          ApiConstants.cleanerMe,
          options: Options(headers: {'Authorization': 'Bearer $access'}),
        );
        profile =
            CleanerProfile.fromJson(me.data as Map<String, dynamic>);
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
    try {
      await _dio.post(ApiConstants.logout);
    } catch (_) {}
    await _storage.deleteAll();
  }

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
    final profile =
        CleanerProfile.fromJson(res.data as Map<String, dynamic>);
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
