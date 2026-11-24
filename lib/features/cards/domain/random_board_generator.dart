import 'dart:math';

import 'package:equatable/equatable.dart';

import '../../../core/errors/app_failure.dart';
import '../../../models/game_models.dart';

/// Standard number of cards on every randomized DESI GUESS match board.
const int kRandomBoardSize = 10;

class RandomBoardResult extends Equatable {
  const RandomBoardResult({
    required this.category,
    required this.cards,
    required this.subcategoryCounts,
    required this.boardId,
  });

  final GameCategory category;
  final List<GameCard> cards;
  final Map<String, int> subcategoryCounts;
  final String boardId;

  List<String> get cardIds => cards.map((c) => c.id).toList(growable: false);

  BoardPack toBoardPack() {
    final accentHex = switch (category) {
      GameCategory.who => 0xFF8B5CF6,
      GameCategory.what => 0xFFFF9933,
      GameCategory.where => 0xFF2DD4BF,
      GameCategory.custom => 0xFFEC4899,
    };
    return BoardPack(
      packId: boardId,
      category: category,
      name: '${category.displayName} • Random 10',
      subtitle: '${subcategoryCounts.length} Subcategories Mixed',
      description:
          'Balanced randomized 10-card ${category.displayName} board generated fresh for this match.',
      cards: cards,
      accentHex: accentHex,
      iconName: switch (category) {
        GameCategory.who => 'movie',
        GameCategory.what => 'food',
        GameCategory.where => 'travel',
        GameCategory.custom => 'sparkles',
      },
    );
  }

  @override
  List<Object?> get props => [category, cards, subcategoryCounts, boardId];
}

/// Generates balanced, randomized 10-card boards across all active subcategories
/// of a main category (WHO, WHAT, or WHERE) and assigns distinct secret cards.
class RandomBoardGenerator {
  const RandomBoardGenerator();

  /// Generates exactly [boardSize] (default 10) unique active cards for [category]
  /// using balanced multi-subcategory random sampling.
  ///
  /// Provide [seed] only in deterministic unit tests; omit [seed] in production
  /// to use [Random.secure].
  RandomBoardResult generateBoard({
    required GameCategory category,
    required List<BoardPack> sourcePacks,
    int boardSize = kRandomBoardSize,
    int? seed,
  }) {
    final rng = seed != null ? Random(seed) : Random.secure();

    // 1. Group valid, active, unique cards by subcategory
    final bySubcategory = <String, List<GameCard>>{};
    final seenIds = <String>{};

    for (final pack in sourcePacks) {
      if (pack.category != category) continue;
      final subKey = pack.name.isNotEmpty ? pack.name : pack.packId;
      for (final card in pack.cards) {
        if (!card.isActive || card.id.trim().isEmpty) continue;
        if (card.category != category) continue;
        if (!seenIds.add(card.id)) continue;
        final enriched = card.subcategory.isEmpty
            ? card.copyWith(subcategory: subKey)
            : card;
        bySubcategory.putIfAbsent(subKey, () => <GameCard>[]).add(enriched);
      }
    }

    final totalAvailable = bySubcategory.values.fold<int>(
      0,
      (sum, list) => sum + list.length,
    );
    if (totalAvailable < boardSize) {
      throw GameRuleFailure(
        'Not enough active ${category.displayName} cards to generate a '
        '$boardSize-card board (found $totalAvailable, need $boardSize).',
      );
    }

    // 2. Shuffle cards inside each subcategory and shuffle subcategory order
    final subKeys = bySubcategory.keys.toList();
    for (final key in subKeys) {
      bySubcategory[key]!.shuffle(rng);
    }
    subKeys.shuffle(rng);

    // 3. Vary participating subcategory count slightly when inventory is large
    // so repeated matches produce genuinely varied subcategory mixes while
    // never letting a single subcategory dominate.
    final activeSubKeys = subKeys.toList();
    if (activeSubKeys.length >= 8 && boardSize == 10) {
      final minSubcats = min(activeSubKeys.length, 6);
      final targetSubcats =
          minSubcats + rng.nextInt(activeSubKeys.length - minSubcats + 1);
      final candidateSubset = activeSubKeys.take(targetSubcats).toList();
      final subsetTotal = candidateSubset.fold<int>(
        0,
        (sum, k) => sum + bySubcategory[k]!.length,
      );
      if (subsetTotal >= boardSize) {
        activeSubKeys
          ..clear()
          ..addAll(candidateSubset);
      }
    }

    // 4. Balanced round-robin selection across shuffled subcategories
    final selected = <GameCard>[];
    final counts = <String, int>{};
    final cursor = <String, int>{for (final k in activeSubKeys) k: 0};

    // Pass through activeSubKeys first; if exhausted, fall back to remaining subKeys
    final fallbackKeys = subKeys
        .where((k) => !activeSubKeys.contains(k))
        .toList();
    final pools = [activeSubKeys, fallbackKeys];

    for (final pool in pools) {
      var madeProgress = true;
      while (selected.length < boardSize && madeProgress) {
        madeProgress = false;
        final roundOrder = pool.toList()..shuffle(rng);
        for (final key in roundOrder) {
          if (selected.length >= boardSize) break;
          final list = bySubcategory[key]!;
          final idx = cursor[key] ?? 0;
          if (idx < list.length) {
            selected.add(list[idx]);
            cursor[key] = idx + 1;
            counts[key] = (counts[key] ?? 0) + 1;
            madeProgress = true;
          }
        }
      }
    }

    // 5. Shuffle final board display order & validate invariants
    selected.shuffle(rng);
    final uniqueCheck = selected.map((c) => c.id).toSet();
    if (selected.length != boardSize || uniqueCheck.length != boardSize) {
      throw GameRuleFailure(
        'Board generation invariant failed: expected $boardSize unique cards.',
      );
    }

    return RandomBoardResult(
      category: category,
      cards: List.unmodifiable(selected),
      subcategoryCounts: Map.unmodifiable(counts),
      boardId:
          'random_${category.name}_${DateTime.now().millisecondsSinceEpoch}_${rng.nextInt(9999)}',
    );
  }

  /// Assigns two guaranteed-distinct secret card IDs from [boardCards].
  ({String player1SecretId, String player2SecretId}) assignDistinctSecrets({
    required List<GameCard> boardCards,
    int? seed,
  }) {
    if (boardCards.length < 2) {
      throw const GameRuleFailure(
        'At least 2 cards are required to assign distinct secret cards.',
      );
    }
    final rng = seed != null ? Random(seed) : Random.secure();
    final shuffled = boardCards.toList()..shuffle(rng);
    final p1Secret = shuffled[0].id;
    final p2Secret = shuffled[1].id;
    if (p1Secret == p2Secret) {
      throw const GameRuleFailure('Assigned secret cards must be distinct.');
    }
    return (player1SecretId: p1Secret, player2SecretId: p2Secret);
  }
}
