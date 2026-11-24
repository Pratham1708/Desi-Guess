import 'package:desi_guess/core/errors/app_failure.dart';
import 'package:desi_guess/features/cards/data/card_repository.dart';
import 'package:desi_guess/features/game/domain/game_engine.dart';
import 'package:desi_guess/models/game_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = GameEngine();
  final cardRepo = CardRepository();
  final cricketersPack = cardRepo.findPackById('who_indian_cricketers')!;

  GameMatchState createActiveMatch({GameMode mode = GameMode.local}) {
    var state = engine.createMatch(
      matchId: 'm_test_1',
      mode: mode,
      pack: cricketersPack,
      player1Id: 'p1',
      player1Name: 'Aarav',
      player2Id: 'p2',
      player2Name: 'Meera',
    );
    state = engine.selectSecretCard(
      state: state,
      playerId: 'p1',
      cardId: 'cr_01', // Virat Kohli
    );
    state = engine.acknowledgeHandoff(state);
    state = engine.selectSecretCard(
      state: state,
      playerId: 'p2',
      cardId: 'cr_02', // MS Dhoni
    );
    state = engine.acknowledgeHandoff(state);
    return state;
  }

  group('DESI GUESS GameEngine — Five-Heart & Deduction Rules', () {
    test('both players start with 5 hearts and selectingSecrets status', () {
      final state = engine.createMatch(
        matchId: 'm_init',
        mode: GameMode.local,
        pack: cricketersPack,
        player1Id: 'p1',
        player1Name: 'Aarav',
        player2Id: 'p2',
        player2Name: 'Meera',
      );
      expect(state.player1.hearts, 5);
      expect(state.player2.hearts, 5);
      expect(state.status, MatchStatus.selectingSecrets);
      expect(state.remainingCardsFor('p1'), 25);
    });

    test('secret selection privacy hides opponent secret until completion', () {
      final state = createActiveMatch();
      final p1View = state.redactedFor('p1');
      final p2View = state.redactedFor('p2');

      expect(p1View.player1.secretCardId, 'cr_01');
      expect(p1View.player2.secretCardId, isNull);
      expect(p2View.player2.secretCardId, 'cr_02');
      expect(p2View.player1.secretCardId, isNull);
    });

    test('card elimination & restoration never consume hearts', () {
      var state = createActiveMatch();
      state = engine.toggleCardElimination(
        state: state,
        playerId: 'p1',
        cardId: 'cr_03',
      );
      expect(state.player1.eliminatedCardIds, contains('cr_03'));
      // 25 total cards minus 1 MY CARD secret = 24 opponent candidates; eliminating 1 leaves 23
      expect(state.remainingCardsFor('p1'), 23);
      expect(state.player1.hearts, 5);

      // Restore card
      state = engine.toggleCardElimination(
        state: state,
        playerId: 'p1',
        cardId: 'cr_03',
      );
      expect(state.player1.eliminatedCardIds, isEmpty);
      expect(state.remainingCardsFor('p1'), 24);
      expect(state.player1.hearts, 5);
    });

    test('unlimited normal questions & answers do not deduct hearts', () {
      var state = createActiveMatch();
      for (var i = 0; i < 8; i++) {
        state = engine.submitQuestion(
          state: state,
          askerId: 'p1',
          questionText: 'Question #$i: Are you a wicketkeeper?',
          entryId: 'q_$i',
        );
        state = engine.submitAnswer(
          state: state,
          responderId: 'p2',
          answerText: i.isEven ? 'Yes' : 'No',
        );
      }
      expect(state.player1.hearts, 5);
      expect(state.player2.hearts, 5);
      expect(state.player1.questionsAsked, 8);
      expect(state.questionHistory.length, 8);
      expect(state.questionHistory.last.answer, 'No');
    });

    test('player cannot answer their own question or ask out of turn', () {
      var state = createActiveMatch();
      expect(
        () => engine.submitQuestion(
          state: state,
          askerId: 'p2',
          questionText: 'Out of turn?',
          entryId: 'q_bad',
        ),
        throwsA(isA<GameRuleFailure>()),
      );

      state = engine.submitQuestion(
        state: state,
        askerId: 'p1',
        questionText: 'Are you a bowler?',
        entryId: 'q_1',
      );
      expect(
        () => engine.submitAnswer(
          state: state,
          responderId: 'p1',
          answerText: 'Yes',
        ),
        throwsA(isA<GameRuleFailure>()),
      );
    });

    test('correct final guess immediately wins the game', () {
      final state = createActiveMatch();
      final eval = engine.submitFinalGuess(
        state: state,
        guesserId: 'p1',
        guessedCardId: 'cr_02', // MS Dhoni
        entryId: 'g_win',
      );
      expect(eval.outcome, GuessOutcome.correctWin);
      expect(eval.state.isCompleted, isTrue);
      expect(eval.state.winnerId, 'p1');
      expect(eval.state.player1.hearts, 5);
      // Both secrets revealed after completion
      expect(eval.state.redactedFor('p1').player2.secretCardId, 'cr_02');
    });

    test(
      'incorrect final guess deducts 1 heart and blocks double guess in same turn',
      () {
        final state = createActiveMatch();
        final eval = engine.submitFinalGuess(
          state: state,
          guesserId: 'p1',
          guessedCardId: 'cr_03', // Wrong
          entryId: 'g_1',
        );
        expect(eval.outcome, GuessOutcome.incorrectHeartLost);
        expect(eval.state.player1.hearts, 4);
        expect(eval.state.player1.incorrectGuesses, 1);
        expect(eval.state.isCompleted, isFalse);

        // Edge case: attempting a second final guess in the same turn
        expect(
          () => engine.submitFinalGuess(
            state: eval.state,
            guesserId: 'p1',
            guessedCardId: 'cr_02',
            entryId: 'g_2',
          ),
          throwsA(isA<GameRuleFailure>()),
        );
      },
    );

    test(
      'incorrect guess auto-switches turn, resets guess limit, requires handoff',
      () {
        final state = createActiveMatch();
        expect(state.currentTurnPlayerId, 'p1');
        final eval = engine.submitFinalGuess(
          state: state,
          guesserId: 'p1',
          guessedCardId: 'cr_03',
          entryId: 'g_auto',
        );
        expect(eval.outcome, GuessOutcome.incorrectHeartLost);
        expect(eval.state.player1.hearts, 4);
        expect(eval.state.player2.hearts, 5);
        expect(eval.state.currentTurnPlayerId, 'p2');
        expect(eval.state.turnNumber, state.turnNumber + 1);
        expect(eval.state.guessAttemptedThisTurn, isFalse);
        expect(eval.state.requiresPrivacyHandoff, isTrue);
        expect(eval.state.handoffTargetPlayerId, 'p2');
        expect(eval.state.isCompleted, isFalse);

        // Next player receives a normal turn and can guess (and win).
        final p2Turn = engine.acknowledgeHandoff(eval.state);
        final win = engine.submitFinalGuess(
          state: p2Turn,
          guesserId: 'p2',
          guessedCardId: 'cr_01',
          entryId: 'g_p2_win',
        );
        expect(win.outcome, GuessOutcome.correctWin);
        expect(win.state.winnerId, 'p2');
      },
    );

    test(
      'losing last heart ends the match with results instead of switching turn',
      () {
        var state = createActiveMatch();
        for (var i = 0; i < 4; i++) {
          final e = engine.submitFinalGuess(
            state: state,
            guesserId: 'p1',
            guessedCardId: 'cr_03',
            entryId: 'g_a_$i',
          );
          state = engine.acknowledgeHandoff(e.state);
          final e2 = engine.submitFinalGuess(
            state: state,
            guesserId: 'p2',
            guessedCardId: 'cr_03',
            entryId: 'g_b_$i',
          );
          state = engine.acknowledgeHandoff(e2.state);
        }
        expect(state.player1.hearts, 1);
        expect(state.player2.hearts, 1);
        final fatal = engine.submitFinalGuess(
          state: state,
          guesserId: 'p1',
          guessedCardId: 'cr_04',
          entryId: 'g_fatal_auto',
        );
        expect(fatal.outcome, GuessOutcome.incorrectDefeat);
        expect(fatal.state.player1.hearts, 0);
        expect(fatal.state.isCompleted, isTrue);
        expect(fatal.state.winnerId, 'p2');
        expect(fatal.state.currentTurnPlayerId, 'p1'); // no turn switch
        expect(fatal.state.requiresPrivacyHandoff, isFalse);
      },
    );

    test('incorrect player attempting to submit a guess is rejected', () {
      final state = createActiveMatch();
      expect(
        () => engine.submitFinalGuess(
          state: state,
          guesserId: 'p2',
          guessedCardId: 'cr_01',
          entryId: 'g_bad',
        ),
        throwsA(isA<GameRuleFailure>()),
      );
    });

    test('five incorrect guesses cause zero-heart defeat', () {
      var state = createActiveMatch();
      for (var i = 0; i < 4; i++) {
        final eval = engine.submitFinalGuess(
          state: state,
          guesserId: 'p1',
          guessedCardId: 'cr_03',
          entryId: 'g_wrong_$i',
        );
        expect(eval.outcome, GuessOutcome.incorrectHeartLost);
        // Turn auto-switches to p2; p1 loses nothing else
        expect(eval.state.currentTurnPlayerId, 'p2');
        expect(eval.state.guessAttemptedThisTurn, isFalse);
        state = engine.acknowledgeHandoff(eval.state);
        // p2 wrongly guesses too -> turn auto-returns to p1
        final p2Eval = engine.submitFinalGuess(
          state: state,
          guesserId: 'p2',
          guessedCardId: 'cr_03',
          entryId: 'g_p2_wrong_$i',
        );
        expect(p2Eval.outcome, GuessOutcome.incorrectHeartLost);
        expect(p2Eval.state.currentTurnPlayerId, 'p1');
        state = engine.acknowledgeHandoff(p2Eval.state);
      }

      expect(state.player1.hearts, 1);
      final finalEval = engine.submitFinalGuess(
        state: state,
        guesserId: 'p1',
        guessedCardId: 'cr_04',
        entryId: 'g_fatal',
      );
      expect(finalEval.outcome, GuessOutcome.incorrectDefeat);
      expect(finalEval.state.player1.hearts, 0);
      expect(finalEval.state.isCompleted, isTrue);
      expect(finalEval.state.winnerId, 'p2');
    });

    test('player leaving / forfeiting awards victory to remaining player', () {
      final state = createActiveMatch();
      final forfeited = engine.forfeitMatch(
        state: state,
        leavingPlayerId: 'p1',
      );
      expect(forfeited.isCompleted, isTrue);
      expect(forfeited.winnerId, 'p2');
    });

    test('rematch resets hearts, eliminations, and secrets on same pack', () {
      var state = createActiveMatch();
      state = engine.toggleCardElimination(
        state: state,
        playerId: 'p1',
        cardId: 'cr_05',
      );
      final eval = engine.submitFinalGuess(
        state: state,
        guesserId: 'p1',
        guessedCardId: 'cr_02',
        entryId: 'g_win',
      );
      final rematch = engine.createRematch(
        previous: eval.state,
        newMatchId: 'm_rematch_1',
      );
      expect(rematch.status, MatchStatus.selectingSecrets);
      expect(rematch.player1.hearts, 5);
      expect(rematch.player2.hearts, 5);
      expect(rematch.player1.eliminatedCardIds, isEmpty);
      expect(rematch.player1.secretCardId, isNull);
      expect(rematch.pack.packId, cricketersPack.packId);
    });

    test('local match state survives full JSON serialization round-trip', () {
      var state = createActiveMatch();
      state = engine.toggleCardElimination(
        state: state,
        playerId: 'p1',
        cardId: 'cr_07',
      );
      final decoded = GameMatchState.fromJson(state.toJson());
      expect(decoded, state);
      expect(decoded.player1.eliminatedCardIds, ['cr_07']);
      expect(decoded.player2.secretCardId, 'cr_02');
    });
  });
}
