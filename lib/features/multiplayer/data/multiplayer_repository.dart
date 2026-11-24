import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/firebase_service.dart';
import '../../../models/game_models.dart';

/// Online Multiplayer repository invoking secure Firebase Cloud Functions
/// and subscribing to real-time Firestore room/player streams.
/// Never reads or writes opponent privateSelections.
class MultiplayerRepository {
  MultiplayerRepository({FirebaseService? firebase})
    : _firebase = firebase ?? FirebaseService.instance;

  final FirebaseService _firebase;

  bool get isAvailable => _firebase.isAvailable;

  void _ensureAvailable() {
    if (!_firebase.isAvailable) {
      throw NetworkFailure(_firebase.unavailableReason);
    }
  }

  Future<Map<String, dynamic>> _callFunction(
    String name,
    Map<String, dynamic> payload,
  ) async {
    _ensureAvailable();
    try {
      final callable = _firebase.functions.httpsCallable(name);
      final response = await callable.call<dynamic>(payload);
      return Map<String, dynamic>.from(response.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw RoomFailure(
        e.message ?? 'Server action "$name" failed.',
        code: e.code,
      );
    } catch (e) {
      throw RoomFailure('Online request failed: $e');
    }
  }

  Future<({String roomId, String roomCode})> createRoom({
    required GameCategory category,
    required String boardPackId,
    int? turnTimerSeconds,
  }) async {
    final data = await _callFunction('createRoom', {
      'category': category.name,
      'boardPackId': boardPackId,
      'turnTimerSeconds': turnTimerSeconds,
    });
    return (
      roomId: data['roomId'] as String,
      roomCode: data['roomCode'] as String,
    );
  }

  Future<String> joinRoom(String roomCode) async {
    final data = await _callFunction('joinRoom', {
      'roomCode': roomCode.trim().toUpperCase(),
    });
    return data['roomId'] as String;
  }

  Future<void> leaveRoom(String roomId) async {
    await _callFunction('leaveRoom', {'roomId': roomId});
  }

  Future<void> updateRoomPack({
    required String roomId,
    required GameCategory category,
    required String boardPackId,
  }) async {
    _ensureAvailable();
    await _firebase.firestore
        .collection(AppConstants.colRooms)
        .doc(roomId)
        .update({
          'category': category.name,
          'boardPackId': boardPackId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> setReady({
    required String roomId,
    required String uid,
    required bool ready,
  }) async {
    _ensureAvailable();
    await _firebase.firestore
        .collection(AppConstants.colRoomPlayers)
        .doc('${roomId}_$uid')
        .update({
          'ready': ready,
          'connected': true,
          'lastSeenAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> updatePresence({
    required String roomId,
    required String uid,
    required bool connected,
  }) async {
    if (!_firebase.isAvailable) return;
    try {
      await _firebase.firestore
          .collection(AppConstants.colRoomPlayers)
          .doc('${roomId}_$uid')
          .update({
            'connected': connected,
            'lastSeenAt': FieldValue.serverTimestamp(),
          });
    } catch (_) {}
  }

  Future<void> updateEliminatedCards({
    required String roomId,
    required String uid,
    required List<String> eliminatedCardIds,
  }) async {
    _ensureAvailable();
    await _firebase.firestore
        .collection(AppConstants.colRoomPlayers)
        .doc('${roomId}_$uid')
        .update({'eliminatedCardIds': eliminatedCardIds});
  }

  Future<void> startMatch(String roomId) async {
    await _callFunction('startMatch', {'roomId': roomId});
  }

  Future<void> submitSecretSelection({
    required String roomId,
    required String secretCardId,
  }) async {
    await _callFunction('submitSecretSelection', {
      'roomId': roomId,
      'secretCardId': secretCardId,
    });
  }

  Future<Map<String, dynamic>> submitFinalGuess({
    required String roomId,
    required String guessedCardId,
    required String requestId,
  }) async {
    return _callFunction('submitFinalGuess', {
      'roomId': roomId,
      'guessedCardId': guessedCardId,
      'requestId': requestId,
    });
  }

  Future<void> endTurn(String roomId) async {
    await _callFunction('submitAnswer', {
      'roomId': roomId,
      'action': 'endTurn',
    });
  }

  Future<void> requestRematch(String roomId) async {
    await _callFunction('requestRematch', {'roomId': roomId});
  }

  Stream<RoomData?> watchRoom(String roomId) {
    _ensureAvailable();
    return _firebase.firestore
        .collection(AppConstants.colRooms)
        .doc(roomId)
        .snapshots()
        .map((snap) {
          if (!snap.exists || snap.data() == null) return null;
          return RoomData.fromJson({...snap.data()!, 'roomId': snap.id});
        });
  }

  Stream<List<PlayerMatchState>> watchRoomPlayers(String roomId) {
    _ensureAvailable();
    return _firebase.firestore
        .collection(AppConstants.colRoomPlayers)
        .where('roomId', isEqualTo: roomId)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => PlayerMatchState.fromJson(doc.data()))
              .toList(growable: false),
        );
  }

  /// Reads ONLY the signed-in user's own secret card from privateSelections.
  Future<String?> fetchMySecretCardId({
    required String roomId,
    required String myUid,
  }) async {
    if (!_firebase.isAvailable) return null;
    final snap = await _firebase.firestore
        .collection(AppConstants.colPrivateSelections)
        .doc('${roomId}_$myUid')
        .get();
    return snap.data()?['secretCardId'] as String?;
  }
}
