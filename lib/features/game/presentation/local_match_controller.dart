import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/audio_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../models/game_models.dart';
import '../domain/game_engine.dart';

/// Manages Local Multiplayer (Face-to-Face / Pass & Play) state with
/// randomized 10-card boards, automatic distinct secret assignment,
/// and automatic Hive persistence across app restarts.
class LocalMatchController extends StateNotifier<GameMatchState?> {
  LocalMatchController({
    required StorageService storageService,
    required AudioService audioService,
    required this.onMatchCompleted,
    GameEngine gameEngine = const GameEngine(),
  }) : _storage = storageService,
       _audio = audioService,
       _engine = gameEngine,
       super(null) {
    _restorePersistedMatch();
  }

  final StorageService _storage;
  final AudioService _audio;
  final GameEngine _engine;
  final Future<void> Function(MatchResult result) onMatchCompleted;
  final Uuid _uuid = const Uuid();

  void _restorePersistedMatch() {
    final json = _storage.loadActiveLocalMatch();
    if (json == null) return;
    try {
      final restored = GameMatchState.fromJson(json);
      if (!restored.isCompleted) {
        state = restored;
      }
    } catch (_) {
      _storage.clearActiveLocalMatch();
    }
  }

  Future<void> _persist() async {
    final current = state;
    if (current == null || current.isCompleted) {
      await _storage.clearActiveLocalMatch();
    } else {
      await _storage.saveActiveLocalMatch(current.toJson());
    }
  }

  /// Primary match flow: picks ONLY a main category (WHO / WHAT / WHERE),
  /// generates a fresh balanced 10-card board, and assigns 2 distinct secret cards.
  Future<GameMatchState> startRandomizedLocalMatch({
    required GameCategory category,
    required List<BoardPack> sourcePacks,
    required String player1Name,
    required String player2Name,
    String player1Avatar = 'avatar_1',
    String player2Avatar = 'avatar_2',
    int? seed,
  }) async {
    final match = _engine.createRandomizedMatch(
      matchId: 'local_${_uuid.v4().substring(0, 8)}',
      mode: GameMode.local,
      category: category,
      sourcePacks: sourcePacks,
      player1Id: 'player_1',
      player1Name: player1Name.trim().isEmpty ? 'Player 1' : player1Name.trim(),
      player2Id: 'player_2',
      player2Name: player2Name.trim().isEmpty ? 'Player 2' : player2Name.trim(),
      player1Avatar: player1Avatar,
      player2Avatar: player2Avatar,
      seed: seed,
    );
    state = match;
    await _persist();
    await _audio.play(GameSfx.turnChime);
    return match;
  }

  /// Legacy / Custom Board match start (explicit pack with manual or auto secrets).
  Future<GameMatchState> startLocalMatch({
    required BoardPack pack,
    required String player1Name,
    required String player2Name,
    String player1Avatar = 'avatar_1',
    String player2Avatar = 'avatar_2',
  }) async {
    final match = _engine.createMatch(
      matchId: 'local_${_uuid.v4().substring(0, 8)}',
      mode: GameMode.local,
      pack: pack,
      player1Id: 'player_1',
      player1Name: player1Name.trim().isEmpty ? 'Player 1' : player1Name.trim(),
      player2Id: 'player_2',
      player2Name: player2Name.trim().isEmpty ? 'Player 2' : player2Name.trim(),
      player1Avatar: player1Avatar,
      player2Avatar: player2Avatar,
    );
    state = match;
    await _storage.recordRecentPack(pack.packId);
    await _persist();
    await _audio.play(GameSfx.turnChime);
    return match;
  }

  /// Confirms that [playerId] has seen their auto-assigned secret card.
  Future<void> acknowledgeAssignedSecret(String playerId) async {
    final current = state;
    if (current == null) return;
    state = _engine.acknowledgeAssignedSecret(
      state: current,
      playerId: playerId,
    );
    await _audio.play(GameSfx.cardSelect);
    await _persist();
  }

  /// Manual secret selection (used for custom decks without auto-assignment).
  Future<void> selectSecretCard({
    required String playerId,
    required String cardId,
  }) async {
    final current = state;
    if (current == null) return;
    state = _engine.selectSecretCard(
      state: current,
      playerId: playerId,
      cardId: cardId,
    );
    await _audio.play(GameSfx.cardSelect);
    await _persist();
  }

  Future<void> acknowledgeHandoff() async {
    final current = state;
    if (current == null) return;
    state = _engine.acknowledgeHandoff(current);
    await _audio.play(GameSfx.buttonTap);
    await _persist();
  }

  Future<void> toggleEliminateCard(String cardId) async {
    final current = state;
    if (current == null) return;
    state = _engine.toggleCardElimination(
      state: current,
      playerId: current.currentTurnPlayerId,
      cardId: cardId,
    );
    await _audio.play(GameSfx.cardEliminate);
    await _persist();
  }

  Future<void> restoreAllEliminated() async {
    final current = state;
    if (current == null) return;
    state = _engine.restoreAllEliminated(
      state: current,
      playerId: current.currentTurnPlayerId,
    );
    await _audio.play(GameSfx.buttonTap);
    await _persist();
  }

  Future<void> logVerbalQuestion(String questionText, {String? answer}) async {
    final current = state;
    if (current == null) return;
    var next = _engine.submitQuestion(
      state: current,
      askerId: current.currentTurnPlayerId,
      questionText: questionText,
      entryId: _uuid.v4(),
    );
    if (answer != null && answer.trim().isNotEmpty) {
      next = _engine.submitAnswer(
        state: next,
        responderId: next.waitingPlayer.playerId,
        answerText: answer,
      );
    }
    state = next;
    await _persist();
  }

  Future<GuessEvaluation?> submitFinalGuess(String guessedCardId) async {
    final current = state;
    if (current == null) return null;
    final evaluation = _engine.submitFinalGuess(
      state: current,
      guesserId: current.currentTurnPlayerId,
      guessedCardId: guessedCardId,
      entryId: _uuid.v4(),
    );
    state = evaluation.state;

    switch (evaluation.outcome) {
      case GuessOutcome.correctWin:
        await _audio.play(GameSfx.victory);
        final result = evaluation.state.toMatchResult();
        await _storage.saveMatchResult(result);
        await onMatchCompleted(result);
      case GuessOutcome.incorrectHeartLost:
        await _audio.play(GameSfx.heartLoss);
        await _audio.play(GameSfx.turnChime);
      case GuessOutcome.incorrectDefeat:
        await _audio.play(GameSfx.heartLoss);
        final result = evaluation.state.toMatchResult();
        await _storage.saveMatchResult(result);
        await onMatchCompleted(result);
    }

    await _persist();
    return evaluation;
  }

  Future<void> forfeitCurrentPlayer() async {
    final current = state;
    if (current == null) return;
    final ended = _engine.forfeitMatch(
      state: current,
      leavingPlayerId: current.currentTurnPlayerId,
    );
    state = ended;
    final result = ended.toMatchResult();
    await _storage.saveMatchResult(result);
    await onMatchCompleted(result);
    await _persist();
  }

  /// Generates a brand-new randomized 10-card rematch when [sourcePacks] are supplied,
  /// or restarts the same custom pack.
  Future<void> startRematch({List<BoardPack>? sourcePacks}) async {
    final current = state;
    if (current == null) return;
    if (current.pack.category != GameCategory.custom &&
        sourcePacks != null &&
        sourcePacks.isNotEmpty) {
      state = _engine.createRandomizedMatch(
        matchId: 'local_${_uuid.v4().substring(0, 8)}',
        mode: current.mode,
        category: current.pack.category,
        sourcePacks: sourcePacks,
        player1Id: current.player1.playerId,
        player1Name: current.player1.displayName,
        player2Id: current.player2.playerId,
        player2Name: current.player2.displayName,
        player1Avatar: current.player1.avatarId,
        player2Avatar: current.player2.avatarId,
      );
    } else {
      state = _engine.createRematch(
        previous: current,
        newMatchId: 'local_${_uuid.v4().substring(0, 8)}',
      );
    }
    await _audio.play(GameSfx.turnChime);
    await _persist();
  }

  Future<void> clearMatch() async {
    state = null;
    await _storage.clearActiveLocalMatch();
  }
}
