import 'package:desi_guess/core/errors/app_failure.dart';
import 'package:desi_guess/core/services/firebase_service.dart';
import 'package:desi_guess/features/cards/data/card_repository.dart';
import 'package:desi_guess/features/cards/domain/random_board_generator.dart';
import 'package:desi_guess/features/game/domain/game_engine.dart';
import 'package:desi_guess/models/game_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cardRepo = CardRepository();
  const generator = RandomBoardGenerator();
  const engine = GameEngine();

  group('Phase 3 — RandomBoardGenerator (10-Card Balanced Sampling)', () {
    for (final category in [
      GameCategory.who,
      GameCategory.what,
      GameCategory.where,
    ]) {
      test(
        '${category.displayName}: generates exactly 10 unique active cards across multiple subcategories',
        () {
          final packs = cardRepo.packsForCategory(category);
          final board = generator.generateBoard(
            category: category,
            sourcePacks: packs,
            seed: 42,
          );

          expect(board.cards.length, 10);
          expect(board.cardIds.toSet().length, 10);
          expect(board.category, category);
          for (final card in board.cards) {
            expect(card.category, category);
            expect(card.isActive, isTrue);
            expect(card.subcategory.isNotEmpty, isTrue);
          }

          // Balanced distribution: multiple subcategories participate and none dominates
          expect(board.subcategoryCounts.length, greaterThanOrEqualTo(5));
          final maxFromOneSubcat = board.subcategoryCounts.values.reduce(
            (a, b) => a > b ? a : b,
          );
          expect(maxFromOneSubcat, lessThanOrEqualTo(3));
        },
      );
    }

    test('deterministic with same seed and varied across different seeds', () {
      final packs = cardRepo.packsForCategory(GameCategory.who);
      final boardA1 = generator.generateBoard(
        category: GameCategory.who,
        sourcePacks: packs,
        seed: 2026,
      );
      final boardA2 = generator.generateBoard(
        category: GameCategory.who,
        sourcePacks: packs,
        seed: 2026,
      );
      final boardB = generator.generateBoard(
        category: GameCategory.who,
        sourcePacks: packs,
        seed: 9999,
      );

      expect(boardA1.cardIds, boardA2.cardIds);
      expect(boardA1.cardIds, isNot(equals(boardB.cardIds)));
    });

    test(
      'excludes inactive cards and throws when fewer than 10 valid cards exist',
      () {
        final tinyPack = BoardPack(
          packId: 'who_tiny',
          category: GameCategory.who,
          name: 'Tiny',
          description: 'Too small',
          cards: List.generate(
            12,
            (i) => GameCard(
              id: 't_$i',
              name: 'Card $i',
              category: GameCategory.who,
              description: 'Desc',
              isActive: i < 8, // Only 8 active cards -> must fail!
            ),
          ),
        );

        expect(
          () => generator.generateBoard(
            category: GameCategory.who,
            sourcePacks: [tinyPack],
            seed: 1,
          ),
          throwsA(isA<GameRuleFailure>()),
        );
      },
    );
  });

  group('Phase 4 — Automatic Distinct Secret Assignment & Own-Card Exclusion', () {
    test(
      'assigns 2 different secrets on the 10-card board and excludes own card from guesses',
      () {
        final packs = cardRepo.packsForCategory(GameCategory.who);
        final match = engine.createRandomizedMatch(
          matchId: 'rand_1',
          mode: GameMode.local,
          category: GameCategory.who,
          sourcePacks: packs,
          player1Id: 'p1',
          player1Name: 'Aarav',
          player2Id: 'p2',
          player2Name: 'Meera',
          seed: 77,
        );

        final boardIds = match.pack.activeCards.map((c) => c.id).toSet();
        expect(boardIds.length, 10);
        expect(match.player1.secretCardId, isNotNull);
        expect(match.player2.secretCardId, isNotNull);
        expect(match.player1.secretCardId, isNot(match.player2.secretCardId));
        expect(boardIds, contains(match.player1.secretCardId));
        expect(boardIds, contains(match.player2.secretCardId));

        // Privacy redaction hides opponent secret
        expect(match.redactedFor('p1').player2.secretCardId, isNull);
        expect(match.redactedFor('p2').player1.secretCardId, isNull);

        // Acknowledge both secret cards via Privacy Handoff
        var state = engine.acknowledgeAssignedSecret(
          state: match,
          playerId: 'p1',
        );
        expect(state.requiresPrivacyHandoff, isTrue);
        expect(state.handoffTargetPlayerId, 'p2');
        state = engine.acknowledgeHandoff(state);

        state = engine.acknowledgeAssignedSecret(state: state, playerId: 'p2');
        expect(state.status, MatchStatus.active);
        expect(state.requiresPrivacyHandoff, isTrue);
        expect(state.handoffTargetPlayerId, 'p1');
        state = engine.acknowledgeHandoff(state);

        // Own secret card is excluded from opponent-guess candidates (9 out of 10)
        final p1Candidates = state.opponentGuessCandidatesFor('p1');
        expect(p1Candidates.length, 9);
        expect(
          p1Candidates.any((c) => c.id == state.player1.secretCardId),
          isFalse,
        );
        expect(state.remainingCardsFor('p1'), 9);

        // Eliminating own MY CARD secret must fail
        expect(
          () => engine.toggleCardElimination(
            state: state,
            playerId: 'p1',
            cardId: state.player1.secretCardId!,
          ),
          throwsA(isA<GameRuleFailure>()),
        );

        // Guessing own secret card must fail
        expect(
          () => engine.submitFinalGuess(
            state: state,
            guesserId: 'p1',
            guessedCardId: state.player1.secretCardId!,
            entryId: 'g_self',
          ),
          throwsA(isA<GameRuleFailure>()),
        );
      },
    );

    test('ENABLE_FIREBASE defaults to false safely without crashing', () async {
      await FirebaseService.instance.initialize(enabled: false);
      expect(FirebaseService.instance.isEnabledByConfig, isFalse);
      expect(FirebaseService.instance.isAvailable, isFalse);
      expect(
        FirebaseService.instance.unavailableReason,
        contains('ENABLE_FIREBASE=false'),
      );
    });
  });
}
