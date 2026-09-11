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

  // Optional: initialize Firebase for push when you add google-services files
  // await Firebase.initializeApp();

  runApp(
    const ProviderScope(
      child: CleanSeraCleanerApp(),
    ),
  );
}
