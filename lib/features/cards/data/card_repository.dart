import '../../../core/services/storage_service.dart';
import '../../../models/game_models.dart';
import '../domain/random_board_generator.dart';
import 'what_packs.dart';
import 'where_packs.dart';
import 'who_packs_part1.dart';
import 'who_packs_part2.dart';

/// Central catalog of all 450 built-in Indian cards across 24 subcategories
/// plus custom boards and randomized 10-card board generation.
class CardRepository {
  CardRepository({
    StorageService? storageService,
    RandomBoardGenerator generator = const RandomBoardGenerator(),
  }) : _storage = storageService,
       _generator = generator;

  final StorageService? _storage;
  final RandomBoardGenerator _generator;

  late final List<BoardPack> _builtInPacks = List.unmodifiable(
    [
      ...buildWhoPacksPart1(),
      ...buildWhoPacksPart2(),
      ...buildWhatPacks(),
      ...buildWherePacks(),
    ].map(_enrichPackCards),
  );

  static BoardPack _enrichPackCards(BoardPack pack) {
    return pack.copyWith(
      cards: pack.cards
          .map(
            (c) =>
                c.subcategory.isEmpty ? c.copyWith(subcategory: pack.name) : c,
          )
          .toList(growable: false),
    );
  }

  List<BoardPack> get builtInPacks => _builtInPacks;

  List<BoardPack> get customBoards => _storage?.loadCustomBoards() ?? const [];

  List<BoardPack> get allPacks => [..._builtInPacks, ...customBoards];

  List<BoardPack> packsForCategory(GameCategory category) {
    if (category == GameCategory.custom) return customBoards;
    return allPacks
        .where((p) => p.category == category)
        .toList(growable: false);
  }

  List<BoardPack> get featuredPacks =>
      _builtInPacks.where((p) => p.isFeatured).toList(growable: false);

  BoardPack? findPackById(String packId) {
    for (final pack in allPacks) {
      if (pack.packId == packId) return pack;
    }
    return null;
  }

  GameCard? findCardById(String cardId) {
    for (final pack in allPacks) {
      for (final card in pack.cards) {
        if (card.id == cardId) return card;
      }
    }
    return null;
  }

  /// Generates a fresh, balanced 10-card randomized board from all active
  /// subcategories of [category] (WHO, WHAT, or WHERE).
  RandomBoardResult generateRandomBoard({
    required GameCategory category,
    int boardSize = kRandomBoardSize,
    int? seed,
  }) {
    return _generator.generateBoard(
      category: category,
      sourcePacks: packsForCategory(category),
      boardSize: boardSize,
      seed: seed,
    );
  }

  /// Reconstructs an exact 10-card online board from server-provided [cardIds].
  BoardPack? buildBoardPackFromCardIds({
    required GameCategory category,
    required List<String> cardIds,
    String? customPackId,
  }) {
    if (cardIds.isEmpty) {
      return customPackId != null ? findPackById(customPackId) : null;
    }
    final resolved = <GameCard>[];
    for (final id in cardIds) {
      final card = findCardById(id);
      if (card != null) resolved.add(card);
    }
    if (resolved.isEmpty) {
      return customPackId != null ? findPackById(customPackId) : null;
    }
    return BoardPack(
      packId: customPackId ?? 'online_${category.name}',
      category: category,
      name: '${category.displayName} • Online 10',
      subtitle: 'Server-Randomized 10-Card Board',
      description: 'Synchronized 10-card board for this online match.',
      cards: resolved,
      accentHex: switch (category) {
        GameCategory.who => 0xFF8B5CF6,
        GameCategory.what => 0xFFFF9933,
        GameCategory.where => 0xFF2DD4BF,
        GameCategory.custom => 0xFFEC4899,
      },
    );
  }

  List<BoardPack> recentPacks() {
    final ids = _storage?.loadRecentPackIds() ?? const [];
    final found = <BoardPack>[];
    for (final id in ids) {
      final pack = findPackById(id);
      if (pack != null) found.add(pack);
    }
    if (found.isEmpty) {
      return featuredPacks.take(4).toList(growable: false);
    }
    return found;
  }

  Future<void> markPackPlayed(String packId) async {
    await _storage?.recordRecentPack(packId);
  }

  Future<void> saveCustomBoard(BoardPack pack) async {
    await _storage?.saveCustomBoard(pack);
  }

  Future<void> deleteCustomBoard(String packId) async {
    await _storage?.deleteCustomBoard(packId);
  }

  List<GameCard> searchCards(String query, {GameCategory? category}) {
    final q = query.trim().toLowerCase();
    final pool = (category == null ? allPacks : packsForCategory(category))
        .expand((p) => p.activeCards);
    if (q.isEmpty) return pool.toList(growable: false);
    return pool
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.description.toLowerCase().contains(q) ||
              c.subcategory.toLowerCase().contains(q) ||
              c.keywords.any((k) => k.contains(q)),
        )
        .toList(growable: false);
  }
}
