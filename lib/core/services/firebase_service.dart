import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Compile-time Firebase feature flag:
/// - Local / FlutLab default: `--dart-define=ENABLE_FIREBASE=false`
/// - Production / Emulator:   `--dart-define=ENABLE_FIREBASE=true`
const bool kEnableFirebase = bool.fromEnvironment(
  'ENABLE_FIREBASE',
  defaultValue: false,
);

/// Manages Firebase initialization gated strictly behind [kEnableFirebase],
/// emulator routing, and safe offline local execution when disabled.
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  bool _isInitialized = false;
  bool _isEnabledByConfig = kEnableFirebase;
  String? _initError;

  bool get isEnabledByConfig => _isEnabledByConfig;
  bool get isAvailable => _isEnabledByConfig && _isInitialized;
  String? get initError => _initError;

  String get unavailableReason {
    if (!_isEnabledByConfig) {
      return 'Online multiplayer is disabled in Local Mode '
          '(built with ENABLE_FIREBASE=false). '
          'Rebuild with --dart-define=ENABLE_FIREBASE=true and your Firebase config to play online.';
    }
    return 'Firebase could not initialize (${_initError ?? 'missing config'}). '
        'Local multiplayer remains 100% playable offline.';
  }

  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;
  FirebaseFunctions get functions => FirebaseFunctions.instance;
  FirebaseStorage get storage => FirebaseStorage.instance;
  FirebaseAnalytics get analytics => FirebaseAnalytics.instance;

  /// Initializes Firebase ONLY when [enabled] is true (`--dart-define=ENABLE_FIREBASE=true`).
  /// When false, Firebase is never touched so local builds require zero Firebase credentials.
  Future<void> initialize({
    bool enabled = kEnableFirebase,
    FirebaseOptions? options,
    bool useEmulators = false,
    String emulatorHost = '127.0.0.1',
  }) async {
    _isEnabledByConfig = enabled;
    if (!enabled) {
      _isInitialized = false;
      _initError = null;
      debugPrint(
        'DESI GUESS: ENABLE_FIREBASE=false — Skipping Firebase initialization. '
        'Offline Local Multiplayer is fully enabled.',
      );
      return;
    }
    if (_isInitialized) return;
    try {
      if (Firebase.apps.isEmpty) {
        if (options != null) {
          await Firebase.initializeApp(options: options);
        } else {
          await Firebase.initializeApp();
        }
      }
      _isInitialized = true;
      _initError = null;

      if (useEmulators) {
        await auth.useAuthEmulator(emulatorHost, 9099);
        firestore.useFirestoreEmulator(emulatorHost, 8080);
        functions.useFunctionsEmulator(emulatorHost, 5001);
        await storage.useStorageEmulator(emulatorHost, 9199);
      } else {
        await _configureSecurityAndTelemetry();
      }
    } catch (e) {
      _isInitialized = false;
      _initError = e.toString();
      debugPrint(
        'DESI GUESS: Firebase initialization failed ($e). '
        'Continuing cleanly in offline local mode.',
      );
    }
  }

  Future<void> _configureSecurityAndTelemetry() async {
    try {
      if (!kIsWeb) {
        await FirebaseAppCheck.instance.activate(
          androidProvider: kDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.deviceCheck,
        );
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;
      }
    } catch (_) {}
  }

  Future<void> logEvent(String name, [Map<String, Object>? params]) async {
    if (!isAvailable) return;
    try {
      await analytics.logEvent(name: name, parameters: params);
    } catch (_) {}
  }
}
