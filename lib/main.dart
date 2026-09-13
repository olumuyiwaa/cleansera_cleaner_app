import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

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
