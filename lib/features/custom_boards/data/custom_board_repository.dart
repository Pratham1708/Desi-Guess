import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/room_code_generator.dart';
import '../../../models/game_models.dart';

/// Offline-first Custom Boards repository with full Firebase Firestore sync,
/// Firebase Storage custom card image uploads, ownership checks, and share-code joining.
class CustomBoardRepository {
  CustomBoardRepository({
    required StorageService storageService,
    FirebaseService? firebase,
  }) : _storage = storageService,
       _firebase = firebase ?? FirebaseService.instance;

  final StorageService _storage;
  final FirebaseService _firebase;

  bool get isCloudSyncAvailable => _firebase.isAvailable;

  List<BoardPack> loadLocalBoards() => _storage.loadCustomBoards();

  /// Syncs owned AND shared custom boards from Firestore into local Hive cache.
  Future<List<BoardPack>> syncFromCloud(String uid) async {
    if (!_firebase.isAvailable || uid.isEmpty) {
      return _storage.loadCustomBoards();
    }

    try {
      final col = _firebase.firestore.collection(AppConstants.colCustomBoards);
      final [ownedSnap, sharedSnap] = await Future.wait([
        col.where('ownerUid', isEqualTo: uid).get(),
        col
            .where('visibility', isEqualTo: 'shared')
            .where('allowedPlayerUids', arrayContains: uid)
            .get(),
      ]);

      final merged = <String, BoardPack>{};
      for (final local in _storage.loadCustomBoards()) {
        merged[local.packId] = local;
      }
      for (final doc in [...ownedSnap.docs, ...sharedSnap.docs]) {
        final pack = BoardPack.fromJson({...doc.data(), 'packId': doc.id});
        merged[pack.packId] = pack;
        await _storage.saveCustomBoard(pack);
      }
      return merged.values.toList(growable: false);
    } catch (_) {
      return _storage.loadCustomBoards();
    }
  }

  /// Saves a custom board locally and syncs to Firestore when online & signed in.
  Future<BoardPack> saveBoard(BoardPack pack) async {
    await _storage.saveCustomBoard(pack);

    if (_firebase.isAvailable && pack.ownerUid != null) {
      try {
        await _firebase.firestore
            .collection(AppConstants.colCustomBoards)
            .doc(pack.packId)
            .set({
              ...pack.toJson(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      } catch (_) {
        // Remains safely persisted locally in Hive for offline play.
      }
    }
    return pack;
  }

  /// Deletes a custom board locally and in Firestore (owner only).
  Future<void> deleteBoard(String boardId) async {
    await _storage.deleteCustomBoard(boardId);
    if (_firebase.isAvailable) {
      try {
        await _firebase.firestore
            .collection(AppConstants.colCustomBoards)
            .doc(boardId)
            .delete();
      } catch (_) {}
    }
  }

  /// Uploads custom card artwork bytes to Firebase Storage (`custom_cards/{uid}/{cardId}.jpg`).
  Future<String> uploadCustomCardImage({
    required String ownerUid,
    required String cardId,
    required Uint8List imageBytes,
  }) async {
    if (!_firebase.isAvailable) {
      throw const NetworkFailure(
        'Cloud image upload requires Firebase Storage configuration.',
      );
    }
    final ref = _firebase.storage.ref('custom_cards/$ownerUid/$cardId.jpg');
    await ref.putData(imageBytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  /// Toggles board visibility (private <-> shared), generating a 6-char share code
  /// or granting access to an invited friend UID.
  Future<BoardPack> updateSharing({
    required BoardPack board,
    required BoardVisibility visibility,
    String? inviteUid,
  }) async {
    if (_firebase.isAvailable) {
      try {
        final fn = _firebase.functions.httpsCallable('shareCustomBoard');
        final res = await fn.call<dynamic>({
          'boardId': board.packId,
          'visibility': visibility.name,
          'inviteUid': ?inviteUid,
        });
        final data = Map<String, dynamic>.from(res.data as Map);
        final allowed = board.allowedPlayerUids.toSet();
        if (board.ownerUid != null) allowed.add(board.ownerUid!);
        if (inviteUid != null && visibility == BoardVisibility.shared) {
          allowed.add(inviteUid);
        }
        final updated = board.copyWith(
          visibility: visibility,
          shareCode: data['shareCode'] as String?,
          clearShareCode: visibility == BoardVisibility.private,
          allowedPlayerUids: allowed.toList(),
        );
        await _storage.saveCustomBoard(updated);
        return updated;
      } on FirebaseFunctionsException catch (e) {
        throw RoomFailure(
          e.message ?? 'Could not update board sharing.',
          code: e.code,
        );
      }
    }

    // Offline local sharing code preview
    final nextCode = visibility == BoardVisibility.shared
        ? (board.shareCode ?? AppUtils.generateRoomCode())
        : null;
    final updated = board.copyWith(
      visibility: visibility,
      shareCode: nextCode,
      clearShareCode: visibility == BoardVisibility.private,
    );
    await _storage.saveCustomBoard(updated);
    return updated;
  }

  /// Joins a friend's shared custom board using its 6-character share code.
  Future<BoardPack> joinSharedBoardByCode(String shareCode) async {
    final clean = shareCode.trim().toUpperCase();
    if (!AppUtils.isValidRoomCode(clean)) {
      throw const RoomFailure('Enter a valid 6-character board share code.');
    }
    if (!_firebase.isAvailable) {
      throw const NetworkFailure(
        'Joining a friend\'s shared custom board requires Firebase configuration.',
      );
    }

    try {
      final fn = _firebase.functions.httpsCallable('joinCustomBoardByCode');
      final res = await fn.call<dynamic>({'shareCode': clean});
      final data = Map<String, dynamic>.from(res.data as Map);
      final boardId = data['boardId'] as String;

      final doc = await _firebase.firestore
          .collection(AppConstants.colCustomBoards)
          .doc(boardId)
          .get();
      if (!doc.exists || doc.data() == null) {
        throw const RoomFailure('Shared custom board could not be loaded.');
      }
      final pack = BoardPack.fromJson({...doc.data()!, 'packId': doc.id});
      await _storage.saveCustomBoard(pack);
      return pack;
    } on FirebaseFunctionsException catch (e) {
      throw RoomFailure(
        e.message ?? 'Could not join shared custom board.',
        code: e.code,
      );
    }
  }
}
