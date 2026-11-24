import 'package:equatable/equatable.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../models/game_models.dart';
import '../../cards/domain/random_board_generator.dart';

enum GuessOutcome { correctWin, incorrectHeartLost, incorrectDefeat }

class GuessEvaluation extends Equatable {
  const GuessEvaluation({
    required this.state,
    required this.outcome,
    required this.guessedCard,
  });

  final GameMatchState state;
  final GuessOutcome outcome;
  final GameCard guessedCard;

  @override
  List<Object?> get props => [state, outcome, guessedCard];
}

/// Complete, UI-independent state for a DESI GUESS match.
class GameMatchState extends Equatable {
  const GameMatchState({
    required this.matchId,
    required this.mode,
    required this.pack,
    required this.player1,
    required this.player2,
    required this.status,
    required this.currentTurnPlayerId,
    required this.startedAt,
    this.completedAt,
    this.winnerId,
    this.winReason,
    this.guessAttemptedThisTurn = false,
    this.requiresPrivacyHandoff = false,
    this.handoffTargetPlayerId,
    this.questionHistory = const [],
    this.turnNumber = 1,
    this.roomId,
    this.turnTimerSeconds,
  });

  final String matchId;
  final GameMode mode;
  final BoardPack pack;
  final PlayerMatchState player1;
  final PlayerMatchState player2;
  final MatchStatus status;
  final String currentTurnPlayerId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? winnerId;
  final String? winReason;
  final bool guessAttemptedThisTurn;
  final bool requiresPrivacyHandoff;
  final String? handoffTargetPlayerId;
  final List<QuestionEntry> questionHistory;
  final int turnNumber;
  final String? roomId;
  final int? turnTimerSeconds;

  PlayerMatchState playerById(String id) {
    if (player1.playerId == id) return player1;
    if (player2.playerId == id) return player2;
    throw GameRuleFailure('Player $id is not part of this match.');
  }

  PlayerMatchState opponentOf(String id) {
    if (player1.playerId == id) return player2;
    if (player2.playerId == id) return player1;
    throw GameRuleFailure('Player $id is not part of this match.');
  }

  PlayerMatchState get activePlayer => playerById(currentTurnPlayerId);
  PlayerMatchState get waitingPlayer => opponentOf(currentTurnPlayerId);

  bool get isCompleted => status == MatchStatus.completed;

  /// Returns all board cards eligible as opponent-guess candidates for [playerId]
  /// (strictly excludes the player's own secret card).
  List<GameCard> opponentGuessCandidatesFor(String playerId) {
    final p = playerById(playerId);
    return pack.activeCards
        .where((c) => c.id != p.secretCardId)
        .toList(growable: false);
  }

  /// Counts remaining un-eliminated possible opponent cards for [playerId]
  /// (excludes the player's own MY CARD secret).
  int remainingCardsFor(String playerId) {
    final p = playerById(playerId);
    final candidateIds = opponentGuessCandidatesFor(
      playerId,
    ).map((c) => c.id).toSet();
    final eliminatedActive = p.eliminatedCardIds
        .where(candidateIds.contains)
        .length;
    return (candidateIds.length - eliminatedActive).clamp(
      0,
      candidateIds.length,
    );
  }

  GameCard? cardById(String? cardId) {
    if (cardId == null) return null;
    for (final c in pack.activeCards) {
      if (c.id == cardId) return c;
    }
    return null;
  }

  /// Returns a privacy-safe projection where the opponent's secret card is hidden
  /// until the match is completed.
  GameMatchState redactedFor(String viewerPlayerId) {
    if (isCompleted) return this;
    return copyWith(
      player1: player1.playerId == viewerPlayerId
          ? player1
          : player1.copyWith(clearSecret: true),
      player2: player2.playerId == viewerPlayerId
          ? player2
          : player2.copyWith(clearSecret: true),
    );
  }

  MatchResult toMatchResult() {
    if (!isCompleted || winnerId == null) {
      throw const GameRuleFailure('Match is not completed yet.');
    }
    final winner = playerById(winnerId!);
    final loser = opponentOf(winnerId!);
    final end = completedAt ?? DateTime.now();
    return MatchResult(
      matchId: matchId,
      mode: mode,
      category: pack.category,
      packName: pack.name,
      winnerId: winner.playerId,
      winnerName: winner.displayName,
      loserName: loser.displayName,
      winnerHeartsRemaining: winner.hearts,
      loserHeartsRemaining: loser.hearts,
      questionsAsked: questionHistory.where((q) => !q.isFinalGuess).length,
      incorrectGuesses: player1.incorrectGuesses + player2.incorrectGuesses,
      durationSeconds: end.difference(startedAt).inSeconds.clamp(1, 86400),
      winReason: winReason ?? 'Correct Guess',
      completedAt: end,
      player1SecretName: cardById(player1.secretCardId)?.name,
      player2SecretName: cardById(player2.secretCardId)?.name,
      roomId: roomId,
    );
  }

  GameMatchState copyWith({
    BoardPack? pack,
    PlayerMatchState? player1,
    PlayerMatchState? player2,
    MatchStatus? status,
    String? currentTurnPlayerId,
    DateTime? startedAt,
    DateTime? completedAt,
    String? winnerId,
    String? winReason,
    bool? guessAttemptedThisTurn,
    bool? requiresPrivacyHandoff,
    String? handoffTargetPlayerId,
    bool clearHandoffTarget = false,
    List<QuestionEntry>? questionHistory,
    int? turnNumber,
    String? roomId,
    int? turnTimerSeconds,
  }) {
    return GameMatchState(
      matchId: matchId,
      mode: mode,
      pack: pack ?? this.pack,
      player1: player1 ?? this.player1,
      player2: player2 ?? this.player2,
      status: status ?? this.status,
      currentTurnPlayerId: currentTurnPlayerId ?? this.currentTurnPlayerId,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      winnerId: winnerId ?? this.winnerId,
      winReason: winReason ?? this.winReason,
      guessAttemptedThisTurn:
          guessAttemptedThisTurn ?? this.guessAttemptedThisTurn,
      requiresPrivacyHandoff:
          requiresPrivacyHandoff ?? this.requiresPrivacyHandoff,
      handoffTargetPlayerId: clearHandoffTarget
          ? null
          : (handoffTargetPlayerId ?? this.handoffTargetPlayerId),
      questionHistory: questionHistory ?? this.questionHistory,
      turnNumber: turnNumber ?? this.turnNumber,
      roomId: roomId ?? this.roomId,
      turnTimerSeconds: turnTimerSeconds ?? this.turnTimerSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'mode': mode.name,
    'pack': pack.toJson(),
    'player1': player1.toJson(),
    'player2': player2.toJson(),
    'status': status.name,
    'currentTurnPlayerId': currentTurnPlayerId,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'winnerId': winnerId,
    'winReason': winReason,
    'guessAttemptedThisTurn': guessAttemptedThisTurn,
    'requiresPrivacyHandoff': requiresPrivacyHandoff,
    'handoffTargetPlayerId': handoffTargetPlayerId,
    'questionHistory': questionHistory.map((q) => q.toJson()).toList(),
    'turnNumber': turnNumber,
    'roomId': roomId,
    'turnTimerSeconds': turnTimerSeconds,
  };

  factory GameMatchState.fromJson(Map<String, dynamic> json) => GameMatchState(
    matchId: json['matchId'] as String? ?? 'local',
    mode: (json['mode'] as String?) == 'online'
        ? GameMode.online
        : GameMode.local,
    pack: BoardPack.fromJson(Map<String, dynamic>.from(json['pack'] as Map)),
    player1: PlayerMatchState.fromJson(
      Map<String, dynamic>.from(json['player1'] as Map),
    ),
    player2: PlayerMatchState.fromJson(
      Map<String, dynamic>.from(json['player2'] as Map),
    ),
    status: MatchStatus.fromString(
      json['status'] as String? ?? 'selectingSecrets',
    ),
    currentTurnPlayerId: json['currentTurnPlayerId'] as String? ?? 'player_1',
    startedAt:
        DateTime.tryParse(json['startedAt'] as String? ?? '') ?? DateTime.now(),
    completedAt: json['completedAt'] != null
        ? DateTime.tryParse(json['completedAt'] as String)
        : null,
    winnerId: json['winnerId'] as String?,
    winReason: json['winReason'] as String?,
    guessAttemptedThisTurn: json['guessAttemptedThisTurn'] as bool? ?? false,
    requiresPrivacyHandoff: json['requiresPrivacyHandoff'] as bool? ?? false,
    handoffTargetPlayerId: json['handoffTargetPlayerId'] as String?,
    questionHistory: (json['questionHistory'] as List<dynamic>? ?? const [])
        .map((e) => QuestionEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    turnNumber: json['turnNumber'] as int? ?? 1,
    roomId: json['roomId'] as String?,
    turnTimerSeconds: json['turnTimerSeconds'] as int?,
  );

  @override
  List<Object?> get props => [
    matchId,
    mode,
    pack,
    player1,
    player2,
    status,
    currentTurnPlayerId,
    winnerId,
    winReason,
    guessAttemptedThisTurn,
    requiresPrivacyHandoff,
    handoffTargetPlayerId,
    questionHistory,
    turnNumber,
  ];
}

/// Pure, deterministic DESI GUESS rules engine.
/// Independent of Flutter UI and Firebase.
class GameEngine {
  const GameEngine({
    RandomBoardGenerator boardGenerator = const RandomBoardGenerator(),
  }) : _boardGenerator = boardGenerator;

  final RandomBoardGenerator _boardGenerator;

  /// Creates a randomized 10-card match for [category] (WHO, WHAT, or WHERE)
  /// with two guaranteed-distinct secret cards automatically assigned to Player 1 and Player 2.
  GameMatchState createRandomizedMatch({
    required String matchId,
    required GameMode mode,
    required GameCategory category,
    required List<BoardPack> sourcePacks,
    required String player1Id,
    required String player1Name,
    required String player2Id,
    required String player2Name,
    String player1Avatar = 'avatar_1',
    String player2Avatar = 'avatar_2',
    int boardSize = kRandomBoardSize,
    int? seed,
    String? roomId,
    int? turnTimerSeconds,
    bool autoReadySecrets = false,
    DateTime? now,
  }) {
    if (player1Id.trim().isEmpty ||
        player2Id.trim().isEmpty ||
        player1Id == player2Id) {
      throw const GameRuleFailure(
        'Two distinct player IDs are required to start a match.',
      );
    }

    final boardResult = _boardGenerator.generateBoard(
      category: category,
      sourcePacks: sourcePacks,
      boardSize: boardSize,
      seed: seed,
    );
    final secrets = _boardGenerator.assignDistinctSecrets(
      boardCards: boardResult.cards,
      seed: seed != null ? seed + 7919 : null,
    );

    return GameMatchState(
      matchId: matchId,
      mode: mode,
      pack: boardResult.toBoardPack(),
      player1: PlayerMatchState(
        playerId: player1Id,
        displayName: player1Name,
        avatarId: player1Avatar,
        hearts: AppConstants.startingHearts,
        secretCardId: secrets.player1SecretId,
        isReady: autoReadySecrets,
      ),
      player2: PlayerMatchState(
        playerId: player2Id,
        displayName: player2Name,
        avatarId: player2Avatar,
        hearts: AppConstants.startingHearts,
        secretCardId: secrets.player2SecretId,
        isReady: autoReadySecrets,
      ),
      status: autoReadySecrets
          ? MatchStatus.active
          : MatchStatus.selectingSecrets,
      currentTurnPlayerId: player1Id,
      startedAt: now ?? DateTime.now(),
      roomId: roomId,
      turnTimerSeconds: turnTimerSeconds,
    );
  }

  /// Marks that [playerId] has privately viewed & memorized their automatically
  /// assigned secret card. Once both players acknowledge, the match becomes active.
  GameMatchState acknowledgeAssignedSecret({
    required GameMatchState state,
    required String playerId,
  }) {
    if (state.status != MatchStatus.selectingSecrets) {
      throw const GameRuleFailure(
        'Secret assignment acknowledgement is only valid before the match starts.',
      );
    }
    final isP1 = state.player1.playerId == playerId;
    final isP2 = state.player2.playerId == playerId;
    if (!isP1 && !isP2) {
      throw const GameRuleFailure('Only match participants can confirm ready.');
    }
    final p = state.playerById(playerId);
    if (!p.hasSelectedSecret) {
      throw const GameRuleFailure('No secret card has been assigned yet.');
    }

    final updatedP1 = isP1
        ? state.player1.copyWith(isReady: true)
        : state.player1;
    final updatedP2 = isP2
        ? state.player2.copyWith(isReady: true)
        : state.player2;
    final bothReady = updatedP1.isReady && updatedP2.isReady;

    return state.copyWith(
      player1: updatedP1,
      player2: updatedP2,
      status: bothReady ? MatchStatus.active : MatchStatus.selectingSecrets,
      currentTurnPlayerId: state.player1.playerId,
      requiresPrivacyHandoff: state.mode == GameMode.local,
      handoffTargetPlayerId: state.mode == GameMode.local
          ? (bothReady ? updatedP1.playerId : updatedP2.playerId)
          : null,
    );
  }

  GameMatchState createMatch({
    required String matchId,
    required GameMode mode,
    required BoardPack pack,
    required String player1Id,
    required String player1Name,
    required String player2Id,
    required String player2Name,
    String player1Avatar = 'avatar_1',
    String player2Avatar = 'avatar_2',
    String? roomId,
    int? turnTimerSeconds,
    DateTime? now,
  }) {
    if (player1Id.trim().isEmpty ||
        player2Id.trim().isEmpty ||
        player1Id == player2Id) {
      throw const GameRuleFailure(
        'Two distinct player IDs are required to start a match.',
      );
    }
    if (!pack.meetsMinimumSize) {
      throw GameRuleFailure(
        'Board pack "${pack.name}" needs at least '
        '${pack.category.minimumCards} active cards.',
      );
    }
    return GameMatchState(
      matchId: matchId,
      mode: mode,
      pack: pack,
      player1: PlayerMatchState(
        playerId: player1Id,
        displayName: player1Name,
        avatarId: player1Avatar,
        hearts: AppConstants.startingHearts,
      ),
      player2: PlayerMatchState(
        playerId: player2Id,
        displayName: player2Name,
        avatarId: player2Avatar,
        hearts: AppConstants.startingHearts,
      ),
      status: MatchStatus.selectingSecrets,
      currentTurnPlayerId: player1Id,
      startedAt: now ?? DateTime.now(),
      roomId: roomId,
      turnTimerSeconds: turnTimerSeconds,
    );
  }

  /// Locks a player's secret card selection.
  /// In local mode, sets a privacy handoff screen before Player 2 selects
  /// and again before Player 1 begins Turn 1.
  GameMatchState selectSecretCard({
    required GameMatchState state,
    required String playerId,
    required String cardId,
  }) {
    if (state.status != MatchStatus.selectingSecrets) {
      throw const GameRuleFailure(
        'Secret cards can only be selected before the match starts.',
      );
    }
    final card = state.cardById(cardId);
    if (card == null) {
      throw GameRuleFailure('Card "$cardId" is not on this board.');
    }

    final isP1 = state.player1.playerId == playerId;
    final isP2 = state.player2.playerId == playerId;
    if (!isP1 && !isP2) {
      throw const GameRuleFailure('Only match participants can pick a secret.');
    }
    if ((isP1 && state.player1.hasSelectedSecret) ||
        (isP2 && state.player2.hasSelectedSecret)) {
      throw const GameRuleFailure(
        'Your secret card is already locked and cannot be changed.',
      );
    }

    final updatedP1 = isP1
        ? state.player1.copyWith(secretCardId: cardId, isReady: true)
        : state.player1;
    final updatedP2 = isP2
        ? state.player2.copyWith(secretCardId: cardId, isReady: true)
        : state.player2;

    final bothSelected =
        updatedP1.hasSelectedSecret && updatedP2.hasSelectedSecret;

    return state.copyWith(
      player1: updatedP1,
      player2: updatedP2,
      status: bothSelected ? MatchStatus.active : MatchStatus.selectingSecrets,
      currentTurnPlayerId: state.player1.playerId,
      requiresPrivacyHandoff: state.mode == GameMode.local,
      handoffTargetPlayerId: state.mode == GameMode.local
          ? (bothSelected ? updatedP1.playerId : updatedP2.playerId)
          : null,
    );
  }

  /// Eliminates or restores a card on the specified player's board.
  /// Never deducts hearts and never reveals or modifies secret cards.
  GameMatchState toggleCardElimination({
    required GameMatchState state,
    required String playerId,
    required String cardId,
  }) {
    if (state.status != MatchStatus.active) {
      throw const GameRuleFailure('Cards can only be eliminated during play.');
    }
    if (state.cardById(cardId) == null) {
      throw GameRuleFailure('Card "$cardId" does not exist on this board.');
    }

    final target = state.playerById(playerId);
    if (target.secretCardId == cardId) {
      throw const GameRuleFailure(
        'Your own secret card (MY CARD) cannot be eliminated.',
      );
    }
    final updatedIds = target.eliminatedCardIds.toList();
    if (updatedIds.contains(cardId)) {
      updatedIds.remove(cardId);
    } else {
      updatedIds.add(cardId);
    }

    final updatedPlayer = target.copyWith(eliminatedCardIds: updatedIds);
    return state.copyWith(
      player1: state.player1.playerId == playerId
          ? updatedPlayer
          : state.player1,
      player2: state.player2.playerId == playerId
          ? updatedPlayer
          : state.player2,
    );
  }

  /// Restores all eliminated cards for a player.
  GameMatchState restoreAllEliminated({
    required GameMatchState state,
    required String playerId,
  }) {
    final target = state.playerById(playerId);
    final updated = target.copyWith(eliminatedCardIds: const []);
    return state.copyWith(
      player1: state.player1.playerId == playerId ? updated : state.player1,
      player2: state.player2.playerId == playerId ? updated : state.player2,
    );
  }

  /// Logs a normal question. Normal questions are unlimited and NEVER consume hearts.
  GameMatchState submitQuestion({
    required GameMatchState state,
    required String askerId,
    required String questionText,
    required String entryId,
    DateTime? timestamp,
  }) {
    if (state.status != MatchStatus.active) {
      throw const GameRuleFailure(
        'Questions can only be asked during an active match.',
      );
    }
    if (state.currentTurnPlayerId != askerId) {
      throw const GameRuleFailure(
        'Only the active turn player can ask a question.',
      );
    }
    final clean = questionText.trim();
    if (clean.isEmpty) {
      throw const GameRuleFailure('Question cannot be empty.');
    }

    final asker = state.playerById(askerId);
    final updatedAsker = asker.copyWith(
      questionsAsked: asker.questionsAsked + 1,
    );
    final entry = QuestionEntry(
      id: entryId,
      askerId: askerId,
      askerName: asker.displayName,
      question: clean,
      timestamp: timestamp ?? DateTime.now(),
    );

    return state.copyWith(
      player1: state.player1.playerId == askerId ? updatedAsker : state.player1,
      player2: state.player2.playerId == askerId ? updatedAsker : state.player2,
      questionHistory: [...state.questionHistory, entry],
    );
  }

  /// Opponent answers the latest unanswered question (Yes / No / Custom).
  GameMatchState submitAnswer({
    required GameMatchState state,
    required String responderId,
    required String answerText,
  }) {
    if (state.status != MatchStatus.active) {
      throw const GameRuleFailure('Match is not active.');
    }
    if (state.currentTurnPlayerId == responderId) {
      throw const GameRuleFailure('You cannot answer your own question.');
    }
    final responder = state.playerById(responderId);
    final clean = answerText.trim();
    if (clean.isEmpty) {
      throw const GameRuleFailure('Answer cannot be empty.');
    }

    final history = state.questionHistory.toList();
    final idx = history.lastIndexWhere(
      (q) => !q.isFinalGuess && q.answer == null,
    );
    if (idx == -1) {
      throw const GameRuleFailure('There is no pending question to answer.');
    }
    history[idx] = history[idx].copyWith(
      answer: clean,
      answeredBy: responder.displayName,
    );

    return state.copyWith(questionHistory: history);
  }

  /// Evaluates an explicit final guess attempt (max 1 per turn).
  /// - Correct guess: immediate win!
  /// - Incorrect guess: deducts 1 heart; 0 hearts = immediate defeat!
  GuessEvaluation submitFinalGuess({
    required GameMatchState state,
    required String guesserId,
    required String guessedCardId,
    required String entryId,
    DateTime? timestamp,
  }) {
    if (state.status != MatchStatus.active) {
      throw const GameRuleFailure(
        'Final guesses are only allowed during an active match.',
      );
    }
    if (state.currentTurnPlayerId != guesserId) {
      throw const GameRuleFailure(
        'It is not your turn to submit a final guess.',
      );
    }
    if (state.guessAttemptedThisTurn) {
      throw const GameRuleFailure(
        'Only one final guess attempt is allowed per turn.',
      );
    }

    final guesser = state.playerById(guesserId);
    final opponent = state.opponentOf(guesserId);

    if (guesser.hearts <= 0) {
      throw const GameRuleFailure('You have no hearts remaining.');
    }
    if (guesser.secretCardId == guessedCardId) {
      throw const GameRuleFailure(
        'You cannot guess your own secret card! Choose one of your opponent\'s possible cards.',
      );
    }
    final guessedCard = state.cardById(guessedCardId);
    if (guessedCard == null) {
      throw GameRuleFailure('Invalid card "$guessedCardId".');
    }
    if (opponent.secretCardId == null) {
      throw const GameRuleFailure('Opponent has not selected a secret card.');
    }

    final now = timestamp ?? DateTime.now();
    final isCorrect = opponent.secretCardId == guessedCardId;

    final guessLog = QuestionEntry(
      id: entryId,
      askerId: guesserId,
      askerName: guesser.displayName,
      question: 'Final Guess: ${guessedCard.name}',
      answer: isCorrect ? 'Correct!' : 'Wrong (-1 Heart)',
      answeredBy: 'Referee',
      timestamp: now,
      isFinalGuess: true,
      wasCorrectGuess: isCorrect,
    );

    if (isCorrect) {
      final wonState = state.copyWith(
        status: MatchStatus.completed,
        winnerId: guesserId,
        winReason: 'Guessed "${guessedCard.name}" correctly!',
        completedAt: now,
        guessAttemptedThisTurn: true,
        questionHistory: [...state.questionHistory, guessLog],
      );
      return GuessEvaluation(
        state: wonState,
        outcome: GuessOutcome.correctWin,
        guessedCard: guessedCard,
      );
    }

    final remainingHearts = (guesser.hearts - 1).clamp(
      0,
      AppConstants.startingHearts,
    );
    final updatedGuesser = guesser.copyWith(
      hearts: remainingHearts,
      incorrectGuesses: guesser.incorrectGuesses + 1,
    );

    final updatedP1 = state.player1.playerId == guesserId
        ? updatedGuesser
        : state.player1;
    final updatedP2 = state.player2.playerId == guesserId
        ? updatedGuesser
        : state.player2;

    if (remainingHearts == 0) {
      final defeatState = state.copyWith(
        player1: updatedP1,
        player2: updatedP2,
        status: MatchStatus.completed,
        winnerId: opponent.playerId,
        winReason: '${guesser.displayName} ran out of hearts!',
        completedAt: now,
        guessAttemptedThisTurn: true,
        questionHistory: [...state.questionHistory, guessLog],
      );
      return GuessEvaluation(
        state: defeatState,
        outcome: GuessOutcome.incorrectDefeat,
        guessedCard: guessedCard,
      );
    }

    // Incorrect guess (heart lost, player still alive): the turn automatically
    // passes to the next active player. There is no manual "End Turn" action.
    final nextState = _advanceTurn(
      state.copyWith(
        player1: updatedP1,
        player2: updatedP2,
        guessAttemptedThisTurn: true,
        questionHistory: [...state.questionHistory, guessLog],
      ),
      guesserId,
    );
    return GuessEvaluation(
      state: nextState,
      outcome: GuessOutcome.incorrectHeartLost,
      guessedCard: guessedCard,
    );
  }

  /// Automatically passes the turn to the next ACTIVE player (one that still
  /// has hearts) and resets the per-turn guess limit. Eliminated players
  /// (0 hearts) are skipped. Only invoked internally after an incorrect guess.
  GameMatchState _advanceTurn(GameMatchState state, String fromPlayerId) {
    var nextPlayer = state.opponentOf(fromPlayerId);
    if (nextPlayer.hearts <= 0) {
      // Eliminated players never receive a turn.
      nextPlayer = state.playerById(fromPlayerId);
    }
    return state.copyWith(
      currentTurnPlayerId: nextPlayer.playerId,
      guessAttemptedThisTurn: false,
      turnNumber: state.turnNumber + 1,
      requiresPrivacyHandoff: state.mode == GameMode.local,
      handoffTargetPlayerId: state.mode == GameMode.local
          ? nextPlayer.playerId
          : null,
    );
  }

  /// Clears the privacy cover after the phone has been passed.
  GameMatchState acknowledgeHandoff(GameMatchState state) {
    return state.copyWith(
      requiresPrivacyHandoff: false,
      clearHandoffTarget: true,
    );
  }

  /// Completes a match when a player leaves or forfeits.
  GameMatchState forfeitMatch({
    required GameMatchState state,
    required String leavingPlayerId,
    DateTime? timestamp,
  }) {
    if (state.isCompleted) return state;
    final winner = state.opponentOf(leavingPlayerId);
    final leaver = state.playerById(leavingPlayerId);
    return state.copyWith(
      status: MatchStatus.completed,
      winnerId: winner.playerId,
      winReason: '${leaver.displayName} left the match.',
      completedAt: timestamp ?? DateTime.now(),
    );
  }

  /// Starts a fresh rematch with the same players and board pack.
  GameMatchState createRematch({
    required GameMatchState previous,
    required String newMatchId,
    DateTime? now,
  }) {
    return createMatch(
      matchId: newMatchId,
      mode: previous.mode,
      pack: previous.pack,
      player1Id: previous.player1.playerId,
      player1Name: previous.player1.displayName,
      player2Id: previous.player2.playerId,
      player2Name: previous.player2.displayName,
      player1Avatar: previous.player1.avatarId,
      player2Avatar: previous.player2.avatarId,
      roomId: previous.roomId,
      turnTimerSeconds: previous.turnTimerSeconds,
      now: now,
    );
  }
}
