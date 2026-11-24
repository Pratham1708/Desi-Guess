import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../models/game_models.dart';

/// Manages Player Profile, Statistics, Achievements, Leaderboard, and Friends/Invites.
class ProfileRepository {
  ProfileRepository({
    required StorageService storageService,
    FirebaseService? firebase,
  }) : _storage = storageService,
       _firebase = firebase ?? FirebaseService.instance;

  final StorageService _storage;
  final FirebaseService _firebase;
  final Uuid _uuid = const Uuid();

  static const List<Achievement> catalog = [
    Achievement(
      id: 'first_victory',
      title: 'First Victory',
      description: 'Win your very first DESI GUESS match.',
      iconName: 'trophy',
      accentHex: 0xFF22C55E,
    ),
    Achievement(
      id: 'five_streak',
      title: 'Five Consecutive Wins',
      description: 'Build an unstoppable 5-match winning streak.',
      iconName: 'flame',
      accentHex: 0xFFFF9933,
    ),
    Achievement(
      id: 'perfect_guess',
      title: 'Perfect Guess',
      description: 'Win a match with all 5 hearts intact.',
      iconName: 'diamond',
      accentHex: 0xFF2DD4BF,
    ),
    Achievement(
      id: 'comeback_king',
      title: 'Comeback King',
      description: 'Snatch victory while hanging on to your last heart.',
      iconName: 'bolt',
      accentHex: 0xFFEC4899,
    ),
    Achievement(
      id: 'desi_champion',
      title: 'Desi Champion',
      description: 'Reach 1200+ rating or win 10 total matches.',
      iconName: 'crown',
      accentHex: 0xFFFBBF24,
    ),
  ];

  List<Achievement> evaluateAchievements(UserProfile profile) {
    final unlocked = profile.unlockedAchievements.toSet();
    return catalog
        .map((a) => a.copyWith(isUnlocked: unlocked.contains(a.id)))
        .toList(growable: false);
  }

  /// Updates local stats & unlocks achievements cleanly after any match.
  Future<UserProfile> recordLocalMatchOutcome({
    required UserProfile profile,
    required bool didWin,
    required int heartsRemaining,
  }) async {
    final totalGames = profile.totalGames + 1;
    final wins = profile.wins + (didWin ? 1 : 0);
    final losses = profile.losses + (didWin ? 0 : 1);
    final streak = didWin ? profile.currentWinStreak + 1 : 0;
    final bestStreak = streak > profile.bestWinStreak
        ? streak
        : profile.bestWinStreak;
    final perfect =
        profile.perfectGuesses + (didWin && heartsRemaining == 5 ? 1 : 0);
    final comebacks =
        profile.comebackWins + (didWin && heartsRemaining == 1 ? 1 : 0);
    final ratingDelta = didWin ? 25 : -12;
    final newRating = (profile.rating + ratingDelta).clamp(600, 3000);

    final unlocked = profile.unlockedAchievements.toSet();
    if (wins >= 1) unlocked.add('first_victory');
    if (bestStreak >= 5) unlocked.add('five_streak');
    if (perfect >= 1) unlocked.add('perfect_guess');
    if (comebacks >= 1) unlocked.add('comeback_king');
    if (newRating >= 1200 || wins >= 10) unlocked.add('desi_champion');

    final updated = profile.copyWith(
      totalGames: totalGames,
      wins: wins,
      losses: losses,
      rating: newRating,
      currentWinStreak: streak,
      bestWinStreak: bestStreak,
      perfectGuesses: perfect,
      comebackWins: comebacks,
      unlockedAchievements: unlocked.toList(),
    );

    await _storage.saveLocalProfile(updated);
    return updated;
  }

  Future<UserProfile> updateProfileDetails({
    required UserProfile profile,
    required String username,
    required String avatarId,
  }) async {
    final updated = profile.copyWith(username: username, avatarId: avatarId);
    await _storage.saveLocalProfile(updated);
    if (_firebase.isAvailable) {
      try {
        await Future.wait([
          _firebase.firestore
              .collection(AppConstants.colUsers)
              .doc(profile.uid)
              .set({
                'username': username,
                'avatar': avatarId,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true)),
          _firebase.firestore
              .collection(AppConstants.colPublicProfiles)
              .doc(profile.uid)
              .set({
                'username': username,
                'avatar': avatarId,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true)),
        ]);
      } catch (_) {}
    }
    return updated;
  }

  /// Fetches live Firestore leaderboard from `publicProfiles` (never reads private `users`),
  /// or returns local player standings cleanly when offline.
  Future<List<LeaderboardEntry>> fetchLeaderboard({
    required String timeframe, // daily, weekly, all_time
    UserProfile? currentUser,
  }) async {
    if (_firebase.isAvailable) {
      try {
        final query = _firebase.firestore
            .collection(AppConstants.colPublicProfiles)
            .orderBy('rating', descending: true)
            .limit(50);
        final snap = await query.get();
        var rank = 1;
        return snap.docs.map((doc) {
          final d = doc.data();
          return LeaderboardEntry(
            rank: rank++,
            uid: doc.id,
            username: d['username'] as String? ?? 'Desi Player',
            avatarId: d['avatar'] as String? ?? 'avatar_1',
            rating: d['rating'] as int? ?? 1000,
            wins: d['wins'] as int? ?? 0,
            totalGames: d['totalGames'] as int? ?? 0,
          );
        }).toList();
      } catch (_) {}
    }

    if (currentUser == null) return const [];
    return [
      LeaderboardEntry(
        rank: 1,
        uid: currentUser.uid,
        username: currentUser.username,
        avatarId: currentUser.avatarId,
        rating: currentUser.rating,
        wins: currentUser.wins,
        totalGames: currentUser.totalGames,
      ),
    ];
  }

  Future<FriendInvite> sendFriendInvite({
    required UserProfile fromUser,
    required String targetUsername,
    String? roomCode,
  }) async {
    final cleanTarget = targetUsername.trim();
    var targetUid = 'pending_${cleanTarget.toLowerCase()}';

    if (_firebase.isAvailable) {
      final lookup = await _firebase.firestore
          .collection(AppConstants.colPublicProfiles)
          .where('username', isEqualTo: cleanTarget)
          .limit(1)
          .get();
      if (lookup.docs.isNotEmpty) {
        targetUid = lookup.docs.first.id;
      }
    }

    final invite = FriendInvite(
      id: _uuid.v4(),
      fromUid: fromUser.uid,
      fromUsername: fromUser.username,
      toUid: targetUid,
      toUsername: cleanTarget,
      status: 'pending',
      createdAt: DateTime.now(),
      roomCode: roomCode,
    );

    if (_firebase.isAvailable) {
      await _firebase.firestore
          .collection(AppConstants.colFriendInvites)
          .doc(invite.id)
          .set({...invite.toJson(), 'createdAt': FieldValue.serverTimestamp()});
    }
    return invite;
  }

  Future<List<FriendInvite>> fetchInvites(UserProfile user) async {
    if (!_firebase.isAvailable) return const [];
    try {
      final col = _firebase.firestore.collection(AppConstants.colFriendInvites);
      final [sentSnap, receivedSnap] = await Future.wait([
        col.where('fromUid', isEqualTo: user.uid).limit(20).get(),
        col.where('toUid', isEqualTo: user.uid).limit(20).get(),
      ]);
      final seen = <String, FriendInvite>{};
      for (final d in [...sentSnap.docs, ...receivedSnap.docs]) {
        seen[d.id] = FriendInvite.fromJson({...d.data(), 'id': d.id});
      }
      return seen.values.toList();
    } catch (_) {
      return const [];
    }
  }
}
