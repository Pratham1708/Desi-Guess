import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/game_models.dart';
import '../constants/app_constants.dart';

/// Unified offline persistence layer backed by Hive & SharedPreferences.
class StorageService {
  StorageService({
    SharedPreferences? sharedPreferences,
    Box<String>? localMatchStore,
    Box<String>? customBoardsStore,
    Box<String>? matchHistoryStore,
    Box<String>? recentPacksStore,
  }) : _prefs = sharedPreferences,
       _localMatchBox = localMatchStore,
       _customBoardsBox = customBoardsStore,
       _matchHistoryBox = matchHistoryStore,
       _recentPacksBox = recentPacksStore;

  SharedPreferences? _prefs;
  Box<String>? _localMatchBox;
  Box<String>? _customBoardsBox;
  Box<String>? _matchHistoryBox;
  Box<String>? _recentPacksBox;

  // In-memory fallback for unit/widget tests where Hive disk isn't initialized.
  final Map<String, String> _memoryMatch = {};
  final Map<String, String> _memoryCustomBoards = {};
  final Map<String, String> _memoryHistory = {};
  final List<String> _memoryRecentPacks = [];
  AppSettings _memorySettings = const AppSettings();
  bool _memoryOnboardingDone = false;
  UserProfile? _memoryProfile;

  Future<void> init() async {
    try {
      await Hive.initFlutter();
      _prefs = await SharedPreferences.getInstance();
      _localMatchBox = await Hive.openBox<String>(AppConstants.boxLocalMatch);
      _customBoardsBox = await Hive.openBox<String>(
        AppConstants.boxCustomBoards,
      );
      _matchHistoryBox = await Hive.openBox<String>(
        AppConstants.boxMatchHistory,
      );
      _recentPacksBox = await Hive.openBox<String>(AppConstants.boxRecentPacks);
    } catch (_) {
      // Fall back cleanly to memory in restricted environments.
    }
  }

  // ---- Settings ----

  AppSettings loadSettings() {
    final p = _prefs;
    if (p == null) return _memorySettings;
    return AppSettings(
      soundEnabled: p.getBool(AppConstants.prefSoundEnabled) ?? true,
      vibrationEnabled: p.getBool(AppConstants.prefVibrationEnabled) ?? true,
      musicEnabled: p.getBool(AppConstants.prefMusicEnabled) ?? false,
      darkMode: p.getBool(AppConstants.prefDarkMode) ?? true,
      languageCode: p.getString(AppConstants.prefLanguageCode) ?? 'en',
      analyticsEnabled: p.getBool(AppConstants.prefPrivacyAnalytics) ?? true,
      allowFriendInvites:
          p.getBool(AppConstants.prefAllowFriendInvites) ?? true,
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    _memorySettings = settings;
    final p = _prefs;
    if (p == null) return;
    await p.setBool(AppConstants.prefSoundEnabled, settings.soundEnabled);
    await p.setBool(
      AppConstants.prefVibrationEnabled,
      settings.vibrationEnabled,
    );
    await p.setBool(AppConstants.prefMusicEnabled, settings.musicEnabled);
    await p.setBool(AppConstants.prefDarkMode, settings.darkMode);
    await p.setString(AppConstants.prefLanguageCode, settings.languageCode);
    await p.setBool(
      AppConstants.prefPrivacyAnalytics,
      settings.analyticsEnabled,
    );
    await p.setBool(
      AppConstants.prefAllowFriendInvites,
      settings.allowFriendInvites,
    );
  }

  bool isOnboardingDone() {
    return _prefs?.getBool(AppConstants.prefOnboardingDone) ??
        _memoryOnboardingDone;
  }

  Future<void> setOnboardingDone(bool done) async {
    _memoryOnboardingDone = done;
    await _prefs?.setBool(AppConstants.prefOnboardingDone, done);
  }

  // ---- Local Profile Cache ----

  UserProfile? loadLocalProfile() {
    final raw = _prefs?.getString(AppConstants.prefLocalProfileJson);
    if (raw == null) return _memoryProfile;
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return _memoryProfile;
    }
  }

  Future<void> saveLocalProfile(UserProfile profile) async {
    _memoryProfile = profile;
    await _prefs?.setString(
      AppConstants.prefLocalProfileJson,
      jsonEncode(profile.toJson()),
    );
  }

  // ---- Local Match Persistence ----

  Future<void> saveActiveLocalMatch(Map<String, dynamic> matchJson) async {
    final encoded = jsonEncode(matchJson);
    _memoryMatch['active'] = encoded;
    await _localMatchBox?.put('active', encoded);
  }

  Map<String, dynamic>? loadActiveLocalMatch() {
    final raw = _localMatchBox?.get('active') ?? _memoryMatch['active'];
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearActiveLocalMatch() async {
    _memoryMatch.remove('active');
    await _localMatchBox?.delete('active');
  }

  // ---- Custom Boards ----

  List<BoardPack> loadCustomBoards() {
    final values =
        _customBoardsBox?.values.toList() ??
        _memoryCustomBoards.values.toList();
    final boards = <BoardPack>[];
    for (final raw in values) {
      try {
        boards.add(BoardPack.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {}
    }
    return boards;
  }

  Future<void> saveCustomBoard(BoardPack pack) async {
    final encoded = jsonEncode(pack.toJson());
    _memoryCustomBoards[pack.packId] = encoded;
    await _customBoardsBox?.put(pack.packId, encoded);
  }

  Future<void> deleteCustomBoard(String packId) async {
    _memoryCustomBoards.remove(packId);
    await _customBoardsBox?.delete(packId);
  }

  // ---- Match History ----

  List<MatchResult> loadMatchHistory() {
    final values =
        _matchHistoryBox?.values.toList() ?? _memoryHistory.values.toList();
    final list = <MatchResult>[];
    for (final raw in values) {
      try {
        list.add(MatchResult.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {}
    }
    list.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return list;
  }

  Future<void> saveMatchResult(MatchResult result) async {
    final encoded = jsonEncode(result.toJson());
    _memoryHistory[result.matchId] = encoded;
    await _matchHistoryBox?.put(result.matchId, encoded);
  }

  // ---- Recently Played Packs ----

  List<String> loadRecentPackIds() {
    final raw = _recentPacksBox?.get('ids');
    if (raw == null) return List.unmodifiable(_memoryRecentPacks);
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => e.toString())
          .toList();
    } catch (_) {
      return List.unmodifiable(_memoryRecentPacks);
    }
  }

  Future<void> recordRecentPack(String packId) async {
    final current = loadRecentPackIds().toList();
    current.remove(packId);
    current.insert(0, packId);
    final trimmed = current.take(8).toList();
    _memoryRecentPacks
      ..clear()
      ..addAll(trimmed);
    await _recentPacksBox?.put('ids', jsonEncode(trimmed));
  }
}
