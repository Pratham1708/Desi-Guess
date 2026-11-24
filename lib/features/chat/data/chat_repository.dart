import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/firebase_service.dart';
import '../../../models/game_models.dart';

/// Real-time Firestore chat & question/answer repository for online rooms.
class ChatRepository {
  ChatRepository({FirebaseService? firebase})
    : _firebase = firebase ?? FirebaseService.instance;

  final FirebaseService _firebase;
  final Uuid _uuid = const Uuid();

  Stream<List<ChatMessage>> watchMessages(String roomId, {int limit = 100}) {
    if (!_firebase.isAvailable) {
      return const Stream.empty();
    }
    return _firebase.firestore
        .collection(AppConstants.colMessages)
        .where('roomId', isEqualTo: roomId)
        .orderBy('timestamp', descending: false)
        .limitToLast(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) =>
                    ChatMessage.fromJson({...doc.data(), 'messageId': doc.id}),
              )
              .toList(growable: false),
        );
  }

  Future<void> submitQuestion({
    required String roomId,
    required String question,
  }) async {
    if (!_firebase.isAvailable) {
      throw const NetworkFailure('Firebase is not connected.');
    }
    try {
      final fn = _firebase.functions.httpsCallable('submitQuestion');
      await fn.call<dynamic>({
        'roomId': roomId,
        'message': question.trim(),
        'requestId': _uuid.v4(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw RoomFailure(e.message ?? 'Could not send question.', code: e.code);
    }
  }

  Future<void> submitAnswer({
    required String roomId,
    required ChatMessageType answerType,
    required String message,
    String? questionId,
  }) async {
    if (!_firebase.isAvailable) {
      throw const NetworkFailure('Firebase is not connected.');
    }
    try {
      final fn = _firebase.functions.httpsCallable('submitAnswer');
      await fn.call<dynamic>({
        'roomId': roomId,
        'messageType': answerType.name,
        'message': message.trim(),
        'requestId': _uuid.v4(),
        'questionId': ?questionId,
      });
    } on FirebaseFunctionsException catch (e) {
      throw RoomFailure(e.message ?? 'Could not send answer.', code: e.code);
    }
  }

  Future<void> markMessagesRead({
    required String roomId,
    required String myUid,
    required List<ChatMessage> messages,
  }) async {
    if (!_firebase.isAvailable) return;
    final unread = messages.where((m) => m.senderUid != myUid && !m.isRead);
    if (unread.isEmpty) return;
    final batch = _firebase.firestore.batch();
    for (final msg in unread) {
      batch.update(
        _firebase.firestore
            .collection(AppConstants.colMessages)
            .doc(msg.messageId),
        {'isRead': true},
      );
    }
    try {
      await batch.commit();
    } catch (_) {}
  }
}
