import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // timeago ships Dutch messages built in, but they aren't registered by
  // default — without this, timeago.format(date, locale: 'nl') silently
  // falls back to English ("3 hours ago" instead of "3 uur geleden").
  timeago.setLocaleMessages('nl', timeago.NlMessages());

  // Firebase is initialized lazily by PushService the first time a cleaner
  // is authenticated (see AuthNotifier / PushService.registerToken), rather
  // than unconditionally here — this keeps app startup working even on a
  // build without google-services.json/GoogleService-Info.plist configured.

  runApp(
    const ProviderScope(
      child: CleanSeraCleanerApp(),
    ),
  );
}
