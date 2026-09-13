import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';

/// Wraps Firebase Cloud Messaging setup for the cleaner app: initializing
/// Firebase, requesting notification permission, and keeping the backend's
/// CleanerDeviceToken record in sync with this device's current token.
///
/// Registration happens both right after login (so a fresh session is
/// registered immediately) and on every app bootstrap for an already-logged
/// -in cleaner (since FCM tokens rotate — re-registering on each cold start
/// is the standard way to handle that without a dedicated refresh listener
/// surviving app restarts).
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _firebaseReady = false;

  Future<void> ensureInitialized() async {
    if (_firebaseReady) return;
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (e) {
      // Missing google-services.json / GoogleService-Info.plist in this
      // build, or Firebase already initialized elsewhere — either way, push
      // just won't work on this build. Never let it crash the app.
      debugPrint('PushService: Firebase.initializeApp failed — push disabled ($e)');
    }
  }

  /// Call after a successful login, and once at app bootstrap for an
  /// already-authenticated session. No-ops quietly if Firebase isn't
  /// configured for this build or the user denies notification permission.
  Future<void> registerToken(Dio dio) async {
    await ensureInitialized();
    if (!_firebaseReady) return;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!granted) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await dio.post(
        ApiConstants.registerFcm,
        data: {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
      );

      // Keep the backend in sync if the token rotates while the app is
      // running (not just at the next cold start).
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          await dio.post(ApiConstants.registerFcm, data: {
            'token': newToken,
            'platform': Platform.isIOS ? 'ios' : 'android',
          });
        } catch (e) {
          debugPrint('PushService: token refresh registration failed ($e)');
        }
      });
    } catch (e) {
      // Best-effort — a cleaner with push notifications not working is a
      // degraded experience, not a broken one (they still see assignments
      // in-app), so this never surfaces as an error to the user.
      debugPrint('PushService: registerToken failed ($e)');
    }
  }

  /// Call on logout so a shared/reset device stops receiving this cleaner's
  /// job-assignment pushes once they've signed out of it.
  Future<void> unregisterToken(Dio dio) async {
    if (!_firebaseReady) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await dio.delete(ApiConstants.registerFcm, data: {'token': token});
    } catch (e) {
      debugPrint('PushService: unregisterToken failed ($e)');
    }
  }
}
