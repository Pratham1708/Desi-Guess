/// Core game rules, board minimums, storage keys, and Firestore collections.
abstract final class AppConstants {
  static const String appName = 'DESI GUESS';
  static const String appTagline = 'Ask Sharp. Eliminate Smart. Guess Desi.';

  // Core Game Rules
  static const int startingHearts = 5;
  static const int maxFinalGuessesPerTurn = 1;
  static const int roomCodeLength = 6;
  static const int roomExpirationMinutes = 60;
  static const int defaultTurnTimerSeconds = 60;

  // Minimum playable board sizes
  static const int minWhoCards = 25;
  static const int minWhatCards = 15;
  static const int minWhereCards = 10;
  static const int minCustomCards = 6;

  // Firestore Collections
  static const String colUsers = 'users';
  static const String colPublicProfiles = 'publicProfiles';
  static const String colRooms = 'rooms';
  static const String colRoomPlayers = 'roomPlayers';
  static const String colPrivateSelections = 'privateSelections';
  static const String colMessages = 'messages';
  static const String colGameHistory = 'gameHistory';
  static const String colCardPacks = 'cardPacks';
  static const String colFriendInvites = 'friendInvites';
  static const String colCustomBoards = 'customBoards';

  // Hive Box Names
  static const String boxLocalMatch = 'local_match_box';
  static const String boxCustomBoards = 'custom_boards_box';
  static const String boxProfileCache = 'profile_cache_box';
  static const String boxMatchHistory = 'match_history_box';
  static const String boxRecentPacks = 'recent_packs_box';

  // SharedPreferences Keys
  static const String prefSoundEnabled = 'sound_enabled';
  static const String prefVibrationEnabled = 'vibration_enabled';
  static const String prefMusicEnabled = 'music_enabled';
  static const String prefDarkMode = 'dark_mode';
  static const String prefLanguageCode = 'language_code';
  static const String prefOnboardingDone = 'onboarding_done';
  static const String prefPrivacyAnalytics = 'privacy_analytics';
  static const String prefAllowFriendInvites = 'allow_friend_invites';
  static const String prefLocalProfileJson = 'local_profile_json';
}
