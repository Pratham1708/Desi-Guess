import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/services/audio_service.dart';
import '../core/services/storage_service.dart';
import '../features/authentication/data/auth_repository.dart';
import '../features/cards/data/card_repository.dart';
import '../features/chat/data/chat_repository.dart';
import '../features/custom_boards/data/custom_board_repository.dart';
import '../features/game/domain/game_engine.dart';
import '../features/game/presentation/local_match_controller.dart';
import '../features/multiplayer/data/multiplayer_repository.dart';
import '../features/profile/data/profile_repository.dart';
import '../models/game_models.dart';

/// Must be overridden in ProviderScope at startup after StorageService.init().
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final audioServiceProvider = Provider<AudioService>((ref) {
  final settings = ref.watch(settingsProvider);
  final service = AudioService(
    enabled: settings.soundEnabled,
    hapticsEnabled: settings.vibrationEnabled,
  );
  ref.onDispose(service.dispose);
  return service;
});

final cardRepositoryProvider = Provider<CardRepository>((ref) {
  return CardRepository(storageService: ref.watch(storageServiceProvider));
});

final customBoardRepositoryProvider = Provider<CustomBoardRepository>((ref) {
  return CustomBoardRepository(
    storageService: ref.watch(storageServiceProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(storageService: ref.watch(storageServiceProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(storageService: ref.watch(storageServiceProvider));
});

final multiplayerRepositoryProvider = Provider<MultiplayerRepository>((ref) {
  return MultiplayerRepository();
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

// ---- App Settings ----

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._storage) : super(_storage.loadSettings());

  final StorageService _storage;

  Future<void> _update(AppSettings next) async {
    state = next;
    await _storage.saveSettings(next);
  }

  Future<void> setSoundEnabled(bool v) =>
      _update(state.copyWith(soundEnabled: v));
  Future<void> setVibrationEnabled(bool v) =>
      _update(state.copyWith(vibrationEnabled: v));
  Future<void> setMusicEnabled(bool v) =>
      _update(state.copyWith(musicEnabled: v));
  Future<void> setDarkMode(bool v) => _update(state.copyWith(darkMode: v));
  Future<void> setLanguageCode(String code) =>
      _update(state.copyWith(languageCode: code));
  Future<void> setAnalyticsEnabled(bool v) =>
      _update(state.copyWith(analyticsEnabled: v));
  Future<void> setAllowFriendInvites(bool v) =>
      _update(state.copyWith(allowFriendInvites: v));
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
  return SettingsNotifier(ref.watch(storageServiceProvider));
});

// ---- Authentication & User Profile ----

class AuthNotifier extends StateNotifier<UserProfile?> {
  AuthNotifier(this._authRepo, this._profileRepo)
    : super(_authRepo.getCurrentProfile());

  final AuthRepository _authRepo;
  final ProfileRepository _profileRepo;

  Future<void> signInWithEmail(String email, String password) async {
    state = await _authRepo.signInWithEmail(email: email, password: password);
  }

  Future<void> registerWithEmail({
    required String username,
    required String email,
    required String password,
    required String avatarId,
  }) async {
    state = await _authRepo.registerWithEmail(
      username: username,
      email: email,
      password: password,
      avatarId: avatarId,
    );
  }

  Future<void> signInAsGuest({
    required String username,
    String avatarId = 'avatar_1',
  }) async {
    state = await _authRepo.signInAsGuest(
      username: username,
      avatarId: avatarId,
    );
  }

  Future<void> updateProfile({
    required String username,
    required String avatarId,
  }) async {
    final current = state;
    if (current == null) return;
    state = await _profileRepo.updateProfileDetails(
      profile: current,
      username: username,
      avatarId: avatarId,
    );
  }

  Future<void> recordMatchOutcome({
    required bool didWin,
    required int heartsRemaining,
  }) async {
    final current = state;
    if (current == null) return;
    state = await _profileRepo.recordLocalMatchOutcome(
      profile: current,
      didWin: didWin,
      heartsRemaining: heartsRemaining,
    );
  }

  Future<void> signOut() async {
    await _authRepo.signOut();
    state = null;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, UserProfile?>((ref) {
  return AuthNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(profileRepositoryProvider),
  );
});

// ---- Custom Boards (Hive + Firebase Sync & Sharing) ----

class CustomBoardsNotifier extends StateNotifier<List<BoardPack>> {
  CustomBoardsNotifier(this._repo, this._uid) : super(_repo.loadLocalBoards()) {
    if (_uid != null && _repo.isCloudSyncAvailable) {
      syncFromCloud();
    }
  }

  final CustomBoardRepository _repo;
  final String? _uid;
  final Uuid _uuid = const Uuid();

  Future<void> syncFromCloud() async {
    final uid = _uid;
    if (uid == null) return;
    state = await _repo.syncFromCloud(uid);
  }

  Future<BoardPack> createBoard({
    required String name,
    required String description,
    required int accentHex,
    String? ownerUid,
    BoardVisibility visibility = BoardVisibility.private,
  }) async {
    final effectiveOwner = ownerUid ?? _uid ?? 'local_owner';
    final pack = BoardPack(
      packId: 'custom_${_uuid.v4().substring(0, 8)}',
      category: GameCategory.custom,
      name: name.trim(),
      subtitle: 'Custom Board',
      description: description.trim().isEmpty
          ? 'Player-created custom DESI GUESS deck.'
          : description.trim(),
      cards: const [],
      accentHex: accentHex,
      iconName: 'sparkles',
      isCustom: true,
      ownerUid: effectiveOwner,
      visibility: visibility,
      allowedPlayerUids: [effectiveOwner],
    );
    await _repo.saveBoard(pack);
    state = _repo.loadLocalBoards();
    return pack;
  }

  Future<void> addCardToBoard({
    required String boardId,
    required GameCard card,
  }) async {
    final idx = state.indexWhere((b) => b.packId == boardId);
    if (idx == -1) return;
    final updated = state[idx].copyWith(cards: [...state[idx].cards, card]);
    await _repo.saveBoard(updated);
    state = _repo.loadLocalBoards();
  }

  Future<void> removeCardFromBoard({
    required String boardId,
    required String cardId,
  }) async {
    final idx = state.indexWhere((b) => b.packId == boardId);
    if (idx == -1) return;
    final updated = state[idx].copyWith(
      cards: state[idx].cards.where((c) => c.id != cardId).toList(),
    );
    await _repo.saveBoard(updated);
    state = _repo.loadLocalBoards();
  }

  Future<BoardPack?> toggleSharing({
    required String boardId,
    required BoardVisibility visibility,
    String? inviteUid,
  }) async {
    final idx = state.indexWhere((b) => b.packId == boardId);
    if (idx == -1) return null;
    final updated = await _repo.updateSharing(
      board: state[idx],
      visibility: visibility,
      inviteUid: inviteUid,
    );
    state = _repo.loadLocalBoards();
    return updated;
  }

  Future<BoardPack> joinByShareCode(String shareCode) async {
    final joined = await _repo.joinSharedBoardByCode(shareCode);
    state = _repo.loadLocalBoards();
    return joined;
  }

  Future<void> deleteBoard(String boardId) async {
    await _repo.deleteBoard(boardId);
    state = _repo.loadLocalBoards();
  }
}

final customBoardsProvider =
    StateNotifierProvider<CustomBoardsNotifier, List<BoardPack>>((ref) {
      return CustomBoardsNotifier(
        ref.watch(customBoardRepositoryProvider),
        ref.watch(authProvider)?.uid,
      );
    });

// ---- Match History & Last Match Result ----

final lastMatchResultProvider = StateProvider<MatchResult?>((ref) => null);

final matchHistoryProvider = Provider<List<MatchResult>>((ref) {
  ref.watch(lastMatchResultProvider);
  return ref.watch(storageServiceProvider).loadMatchHistory();
});

// ---- Local Match Controller ----

final localMatchProvider =
    StateNotifierProvider<LocalMatchController, GameMatchState?>((ref) {
      return LocalMatchController(
        storageService: ref.watch(storageServiceProvider),
        audioService: ref.watch(audioServiceProvider),
        onMatchCompleted: (result) async {
          ref.read(lastMatchResultProvider.notifier).state = result;
          final didPlayer1Win = result.winnerId == 'player_1';
          await ref
              .read(authProvider.notifier)
              .recordMatchOutcome(
                didWin: didPlayer1Win,
                heartsRemaining: didPlayer1Win
                    ? result.winnerHeartsRemaining
                    : result.loserHeartsRemaining,
              );
        },
      );
    });

// ---- Friends & Invites ----

class FriendsNotifier extends StateNotifier<List<FriendInvite>> {
  FriendsNotifier(this._profileRepo, this._user) : super(const []) {
    if (_user != null) {
      refresh();
    }
  }

  final ProfileRepository _profileRepo;
  final UserProfile? _user;

  Future<void> refresh() async {
    final u = _user;
    if (u == null) return;
    state = await _profileRepo.fetchInvites(u);
  }

  Future<void> sendInvite(String targetUsername, {String? roomCode}) async {
    final u = _user;
    if (u == null) return;
    final invite = await _profileRepo.sendFriendInvite(
      fromUser: u,
      targetUsername: targetUsername,
      roomCode: roomCode,
    );
    state = [invite, ...state];
  }
}

final friendsProvider =
    StateNotifierProvider<FriendsNotifier, List<FriendInvite>>((ref) {
      return FriendsNotifier(
        ref.watch(profileRepositoryProvider),
        ref.watch(authProvider),
      );
    });

// ---- Leaderboard ----

final leaderboardTimeframeProvider = StateProvider<String>((ref) => 'all_time');

final leaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) async {
  final timeframe = ref.watch(leaderboardTimeframeProvider);
  final user = ref.watch(authProvider);
  return ref
      .watch(profileRepositoryProvider)
      .fetchLeaderboard(timeframe: timeframe, currentUser: user);
});

// ---- Active Online Room Streams ----

final roomStreamProvider = StreamProvider.family<RoomData?, String>((
  ref,
  roomId,
) {
  return ref.watch(multiplayerRepositoryProvider).watchRoom(roomId);
});

final roomPlayersStreamProvider =
    StreamProvider.family<List<PlayerMatchState>, String>((ref, roomId) {
      return ref.watch(multiplayerRepositoryProvider).watchRoomPlayers(roomId);
    });

final chatMessagesStreamProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, roomId) {
      return ref.watch(chatRepositoryProvider).watchMessages(roomId);
    });
