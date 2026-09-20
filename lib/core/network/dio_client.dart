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
        final request = error.requestOptions;
        // Never try to refresh on the auth calls themselves, and only retry a
        // request once. Otherwise a 401 from /auth/refresh re-enters this
        // handler and asks for another refresh.
        final isAuthCall = request.path.contains(ApiConstants.refresh) ||
            request.path.contains(ApiConstants.login);
        final alreadyRetried = request.extra['authRetried'] == true;

        if (error.response?.statusCode == 401 && !isAuthCall && !alreadyRetried) {
          final refreshed = await _tryRefreshToken();
          if (refreshed) {
            request.extra['authRetried'] = true;
            const storage = FlutterSecureStorage();
            final token =
                await storage.read(key: AppConstants.storageAccessToken);
            request.headers['Authorization'] = 'Bearer $token';
            try {
              final response = await dio.fetch(request);
              return handler.resolve(response);
            } on DioException catch (retryError) {
              return handler.next(retryError);
            } catch (_) {
              // fall through to the original error
            }
          }
        }
        return handler.next(error);
      },
    ),
  );

  return dio;
});

/// The refresh call in flight, if any. Several requests fail with 401 at the
/// same moment when the access token expires; each used to start its own
/// refresh. Refresh tokens rotate (single use), so the second refresh was
/// rejected and its failure deleted the tokens the first one had just stored,
/// signing the cleaner out. Everyone now waits on one shared refresh.
Future<bool>? _refreshInFlight;

Future<bool> _tryRefreshToken() {
  final inFlight = _refreshInFlight;
  if (inFlight != null) return inFlight;
  final future = _doRefresh().whenComplete(() => _refreshInFlight = null);
  _refreshInFlight = future;
  return future;
}

Future<bool> _doRefresh() async {
  const storage = FlutterSecureStorage();
  final refresh = await storage.read(key: AppConstants.storageRefreshToken);
  if (refresh == null || refresh.isEmpty) return false;

  // A separate client with no interceptors, so this call can never trigger
  // the refresh logic above.
  final refreshDio = Dio(
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

  try {
    final res = await refreshDio.post(
      ApiConstants.refresh,
      data: {'refreshToken': refresh},
    );
    final data = unwrapEnvelope(res.data);
    final access = data['accessToken'] as String?;
    final newRefresh = data['refreshToken'] as String? ?? refresh;
    if (access == null) return false;
    await storage.write(key: AppConstants.storageAccessToken, value: access);
    await storage.write(
        key: AppConstants.storageRefreshToken, value: newRefresh);
    return true;
  } on DioException catch (e) {
    // Only a rejection from the server means the session is really over. A
    // timeout or no signal (normal for a cleaner in a basement flat or a
    // lift) used to delete the tokens too, logging people out whenever they
    // lost connectivity at the wrong moment.
    final status = e.response?.statusCode;
    if (status == 400 || status == 401 || status == 403) {
      await storage.delete(key: AppConstants.storageAccessToken);
      await storage.delete(key: AppConstants.storageRefreshToken);
    }
    return false;
  } catch (_) {
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
