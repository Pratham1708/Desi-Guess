import 'package:flutter/foundation.dart';

/// Central feature flags for DESI GUESS.
///
/// Online multiplayer, rooms, live chat, invitations, global leaderboards, and
/// cloud account sync are temporarily disabled for the Local Pass-and-Play
/// release. All Firebase and online multiplayer code remains preserved in the
/// repository so it can be re-enabled in a future release simply by flipping
/// [defaultEnableOnlineMultiplayer] to `true` (or building with
/// `--dart-define=ENABLE_ONLINE_MULTIPLAYER=true --dart-define=ENABLE_FIREBASE=true`).
class FeatureFlags {
  FeatureFlags._();

  static const bool defaultEnableOnlineMultiplayer = bool.fromEnvironment(
    'ENABLE_ONLINE_MULTIPLAYER',
    defaultValue: false,
  );

  /// Optional test-only override so automated tests can verify both the
  /// local-only release experience and the preserved online multiplayer code.
  @visibleForTesting
  static bool? debugOverrideOnlineMultiplayer;

  static bool get enableOnlineMultiplayer =>
      debugOverrideOnlineMultiplayer ?? defaultEnableOnlineMultiplayer;

  static bool get enableOnlineRooms => enableOnlineMultiplayer;
  static bool get enableOnlineChat => enableOnlineMultiplayer;
  static bool get enableOnlineInvites => enableOnlineMultiplayer;
  static bool get enableOnlineLeaderboard => enableOnlineMultiplayer;
  static bool get enableCloudAccounts => enableOnlineMultiplayer;
}
