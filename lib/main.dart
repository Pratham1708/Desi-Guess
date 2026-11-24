import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/feature_flags.dart';
import 'core/services/firebase_service.dart';
import 'core/services/storage_service.dart';
import 'shared/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final storage = StorageService();
  await storage.init();

  const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
  const emulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '10.0.2.2',
  );

  // Strictly controlled by FeatureFlags + `--dart-define=ENABLE_FIREBASE=true|false`
  if (FeatureFlags.enableOnlineMultiplayer && kEnableFirebase) {
    await FirebaseService.instance.initialize(
      enabled: true,
      useEmulators: useEmulators,
      emulatorHost: emulatorHost,
    );
  } else {
    await FirebaseService.instance.initialize(enabled: false);
  }

  runApp(
    ProviderScope(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
      child: const DesiGuessApp(),
    ),
  );
}
