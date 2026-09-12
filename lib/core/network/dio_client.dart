import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/api_constants.dart';
import '../constants/app_constants.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: AppConstants.defaultTimeout,
      receiveTimeout: AppConstants.defaultTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        const storage = FlutterSecureStorage();
        final token = await storage.read(key: AppConstants.storageAccessToken);
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Attempt silent refresh once
          final refreshed = await _tryRefreshToken(dio);
          if (refreshed) {
            final opts = error.requestOptions;
            const storage = FlutterSecureStorage();
            final token =
                await storage.read(key: AppConstants.storageAccessToken);
            opts.headers['Authorization'] = 'Bearer $token';
            try {
              final response = await dio.fetch(opts);
              return handler.resolve(response);
            } catch (_) {
              // fall through
            }
          }
        }
        return handler.next(error);
      },
    ),
  );

  return dio;
});

Future<bool> _tryRefreshToken(Dio dio) async {
  const storage = FlutterSecureStorage();
  final refresh = await storage.read(key: AppConstants.storageRefreshToken);
  if (refresh == null || refresh.isEmpty) return false;

  try {
    final res = await dio.post(
      ApiConstants.refresh,
      data: {'refreshToken': refresh},
      options: Options(headers: {'Authorization': null}),
    );
    final data = unwrapEnvelope(res.data);
    final access = data['accessToken'] as String?;
    final newRefresh = data['refreshToken'] as String? ?? refresh;
    if (access == null) return false;
    await storage.write(key: AppConstants.storageAccessToken, value: access);
    await storage.write(
        key: AppConstants.storageRefreshToken, value: newRefresh);
    return true;
  } catch (_) {
    await storage.delete(key: AppConstants.storageAccessToken);
    await storage.delete(key: AppConstants.storageRefreshToken);
    return false;
  }
}

/// Every backend response is wrapped as `{ success, message, data }`. Repos
/// call this once instead of each guessing at the shape — a response with no
/// envelope (or already-unwrapped data, e.g. from a test) passes through
/// unchanged.
Map<String, dynamic> unwrapEnvelope(dynamic raw) {
  if (raw is Map<String, dynamic> && raw['data'] is Map<String, dynamic>) {
    return raw['data'] as Map<String, dynamic>;
  }
  return raw as Map<String, dynamic>;
}

/// Same as [unwrapEnvelope] but for endpoints whose `data` is a JSON array.
List<dynamic> unwrapListEnvelope(dynamic raw) {
  if (raw is List) return raw;
  if (raw is Map<String, dynamic> && raw['data'] is List) {
    return raw['data'] as List;
  }
  return const [];
}
