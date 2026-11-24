import 'package:desi_guess/core/constants/app_constants.dart';
import 'package:desi_guess/core/services/storage_service.dart';
import 'package:desi_guess/features/cards/data/card_repository.dart';
import 'package:desi_guess/models/game_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Indian Card Library & Custom Boards', () {
    final repo = CardRepository();

    test('contains 10 WHO packs, each with >= 25 active cards', () {
      final whoPacks = repo.packsForCategory(GameCategory.who);
      expect(whoPacks.length, 10);
      for (final pack in whoPacks) {
        expect(
          pack.activeCards.length,
          greaterThanOrEqualTo(AppConstants.minWhoCards),
          reason: '${pack.name} must have >= 25 cards',
        );
        expect(pack.meetsMinimumSize, isTrue);
      }
    });

    test('contains 8 WHAT packs, each with >= 15 active cards', () {
      final whatPacks = repo.packsForCategory(GameCategory.what);
      expect(whatPacks.length, 8);
      for (final pack in whatPacks) {
        expect(
          pack.activeCards.length,
          greaterThanOrEqualTo(AppConstants.minWhatCards),
          reason: '${pack.name} must have >= 15 cards',
        );
        expect(pack.meetsMinimumSize, isTrue);
      }
    });

    test('contains 6 WHERE packs, each with >= 10 active cards', () {
      final wherePacks = repo.packsForCategory(GameCategory.where);
      expect(wherePacks.length, 6);
      for (final pack in wherePacks) {
        expect(
          pack.activeCards.length,
          greaterThanOrEqualTo(AppConstants.minWhereCards),
          reason: '${pack.name} must have >= 10 cards',
        );
        expect(pack.meetsMinimumSize, isTrue);
      }
    });

    test('all 450 built-in cards have globally unique IDs', () {
      final allCards = repo.builtInPacks.expand((p) => p.cards).toList();
      final uniqueIds = allCards.map((c) => c.id).toSet();
      expect(allCards.length, 450);
      expect(uniqueIds.length, allCards.length);
    });

    test('search finds iconic Indian cards across categories', () {
      expect(
        repo.searchCards('Virat Kohli').any((c) => c.name == 'Virat Kohli'),
        isTrue,
      );
      expect(
        repo.searchCards('Biryani').any((c) => c.name == 'Biryani'),
        isTrue,
      );
      expect(
        repo.searchCards('Taj Mahal').any((c) => c.name == 'Taj Mahal'),
        isTrue,
      );
    });

    test(
      'custom board saves, loads, and enforces minimum playable size',
      () async {
        final storage = StorageService();
        final customRepo = CardRepository(storageService: storage);

        final board = BoardPack(
          packId: 'custom_squad',
          category: GameCategory.custom,
          name: 'College Squad',
          description: 'Friends board',
          isCustom: true,
          cards: List.generate(
            6,
            (i) => GameCard(
              id: 'c_$i',
              name: 'Friend $i',
              category: GameCategory.custom,
              description: 'Hostel mate #$i',
            ),
          ),
        );

        await customRepo.saveCustomBoard(board);
        expect(customRepo.customBoards.length, 1);
        expect(customRepo.customBoards.first.meetsMinimumSize, isTrue);

        await customRepo.deleteCustomBoard('custom_squad');
        expect(customRepo.customBoards, isEmpty);
      },
    );
  });
}
