import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/room_code_generator.dart';
import '../../../models/game_models.dart';

/// Handles Firebase Authentication (Email/Password, Guest/Anonymous, Registration)
/// and offline local guest profiles when Firebase credentials are not configured yet.
class AuthRepository {
  AuthRepository({
    required StorageService storageService,
    FirebaseService? firebase,
  }) : _storage = storageService,
       _firebase = firebase ?? FirebaseService.instance;

  final StorageService _storage;
  final FirebaseService _firebase;
  final Uuid _uuid = const Uuid();

  bool get isFirebaseReady => _firebase.isAvailable;

  UserProfile? getCurrentProfile() {
    if (_firebase.isAvailable) {
      final user = _firebase.auth.currentUser;
      if (user != null) {
        final cached = _storage.loadLocalProfile();
        if (cached != null && cached.uid == user.uid) return cached;
        return UserProfile(
          uid: user.uid,
          username: user.displayName?.isNotEmpty == true
              ? user.displayName!
              : (user.isAnonymous ? 'Desi Guest' : 'Desi Player'),
          email: user.email ?? '',
          isGuest: user.isAnonymous,
          createdAt: user.metadata.creationTime ?? DateTime.now(),
        );
      }
    }
    return _storage.loadLocalProfile();
  }

  Future<UserProfile> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    if (!cleanEmail.contains('@') || password.length < 6) {
      throw const AuthFailure('Enter a valid email and 6+ character password.');
    }

    if (!_firebase.isAvailable) {
      throw const AuthFailure(
        'Firebase is not configured in this build yet. '
        'Add google-services.json or use Guest Login for Local Play.',
      );
    }

    try {
      final credential = await _firebase.auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final user = credential.user!;
      final profile = await _fetchOrCreateFirestoreUser(
        uid: user.uid,
        username: user.displayName ?? cleanEmail.split('@').first,
        email: cleanEmail,
        isGuest: false,
      );
      await _storage.saveLocalProfile(profile);
      return profile;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Sign-in failed.', code: e.code);
    }
  }

  Future<UserProfile> registerWithEmail({
    required String username,
    required String email,
    required String password,
    String avatarId = 'avatar_1',
  }) async {
    final cleanName = AppUtils.sanitizeUsername(username);
    final cleanEmail = email.trim();
    if (!cleanEmail.contains('@')) {
      throw const AuthFailure('Please enter a valid email address.');
    }
    if (password.length < 6) {
      throw const AuthFailure('Password must be at least 6 characters.');
    }

    if (!_firebase.isAvailable) {
      throw const AuthFailure(
        'Firebase is not configured yet. Follow README.md Firebase Setup '
        'or continue with Guest Login.',
      );
    }

    try {
      final credential = await _firebase.auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final user = credential.user!;
      await user.updateDisplayName(cleanName);
      final profile = await _fetchOrCreateFirestoreUser(
        uid: user.uid,
        username: cleanName,
        email: cleanEmail,
        avatarId: avatarId,
        isGuest: false,
      );
      await _storage.saveLocalProfile(profile);
      return profile;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Registration failed.', code: e.code);
    }
  }

  Future<UserProfile> signInAsGuest({
    required String username,
    String avatarId = 'avatar_1',
  }) async {
    final cleanName = AppUtils.sanitizeUsername(username);

    if (_firebase.isAvailable) {
      try {
        final credential = await _firebase.auth.signInAnonymously();
        final user = credential.user!;
        await user.updateDisplayName(cleanName);
        final profile = await _fetchOrCreateFirestoreUser(
          uid: user.uid,
          username: cleanName,
          email: '',
          avatarId: avatarId,
          isGuest: true,
        );
        await _storage.saveLocalProfile(profile);
        return profile;
      } on FirebaseAuthException catch (e) {
        throw AuthFailure(e.message ?? 'Guest login failed.', code: e.code);
      }
    }

    // Offline local guest session when Firebase isn't configured yet
    final existing = _storage.loadLocalProfile();
    final profile =
        (existing ??
                UserProfile(
                  uid: 'guest_${_uuid.v4().substring(0, 8)}',
                  username: cleanName,
                  avatarId: avatarId,
                  isGuest: true,
                  createdAt: DateTime.now(),
                ))
            .copyWith(username: cleanName, avatarId: avatarId);

    await _storage.saveLocalProfile(profile);
    return profile;
  }

  Future<void> signOut() async {
    if (_firebase.isAvailable) {
      await _firebase.auth.signOut();
    }
  }

  Future<UserProfile> _fetchOrCreateFirestoreUser({
    required String uid,
    required String username,
    required String email,
    String avatarId = 'avatar_1',
    required bool isGuest,
  }) async {
    final docRef = _firebase.firestore
        .collection(AppConstants.colUsers)
        .doc(uid);
    final snap = await docRef.get();
    if (snap.exists && snap.data() != null) {
      return UserProfile.fromJson(snap.data()!);
    }

    final profile = UserProfile(
      uid: uid,
      username: username,
      email: email,
      avatarId: avatarId,
      isGuest: isGuest,
      createdAt: DateTime.now(),
    );

    await docRef.set({
      ...profile.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Sync public leaderboard profile WITHOUT email or private settings
    await _firebase.firestore
        .collection(AppConstants.colPublicProfiles)
        .doc(uid)
        .set({
          'uid': uid,
          'username': username,
          'avatar': avatarId,
          'rating': profile.rating,
          'wins': profile.wins,
          'losses': profile.losses,
          'totalGames': profile.totalGames,
          'bestWinStreak': profile.bestWinStreak,
          'unlockedAchievements': profile.unlockedAchievements,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    return profile;
  }
}
