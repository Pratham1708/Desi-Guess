import '../../models/game_models.dart';

/// Maps all 450 built-in DESI GUESS cards to their dedicated local image asset
/// under `assets/cards/{who,what,where}/<subcategory>/<card_id>.jpg`,
/// with category illustration fallbacks for custom cards.
abstract final class CardArtworkResolver {
  static const String fallbackWho = 'assets/cards/who_bollywood.jpg';
  static const String fallbackWhat = 'assets/cards/what_food.jpg';
  static const String fallbackWhere = 'assets/cards/where_india.jpg';
  static const String fallbackCustom = 'assets/cards/custom_deck.jpg';

  /// Prefix -> organized subcategory folder inside `assets/cards/`.
  static const Map<String, String> prefixToSubfolder = {
    // WHO (10 subcategories, 250 cards)
    'ba': 'who/actors',
    'bact': 'who/actresses',
    'cr': 'who/cricketers',
    'inf': 'who/influencers',
    'pol': 'who/politicians',
    'sg': 'who/singers',
    'ct': 'who/cartoons',
    'tv': 'who/television',
    'sp': 'who/sports',
    'mm': 'who/memes',
    // WHAT (8 subcategories, 128 cards)
    'fd': 'what/food',
    'br': 'what/brands',
    'vh': 'what/vehicles',
    'mv': 'what/movies',
    'hh': 'what/household',
    'tc': 'what/technology',
    'sn': 'what/snacks',
    'pp': 'what/products',
    // WHERE (6 subcategories, 72 cards)
    'cty': 'where/cities',
    'ta': 'where/attractions',
    'st': 'where/states',
    'mn': 'where/monuments',
    'cl': 'where/colleges',
    'ds': 'where/destinations',
  };

  /// Returns the dedicated local image path for [card].
  static String assetForCard(GameCard card) {
    if (card.imageUrl.startsWith('assets/')) {
      return card.imageUrl;
    }

    final underscore = card.id.indexOf('_');
    if (underscore > 0) {
      final prefix = card.id.substring(0, underscore);
      final folder = prefixToSubfolder[prefix];
      if (folder != null) {
        return 'assets/cards/$folder/${card.id}.jpg';
      }
    }

    return fallbackForCategory(card.category);
  }

  static String fallbackForCategory(GameCategory category) =>
      switch (category) {
        GameCategory.who => fallbackWho,
        GameCategory.what => fallbackWhat,
        GameCategory.where => fallbackWhere,
        GameCategory.custom => fallbackCustom,
      };

  static bool hasRemoteImage(GameCard card) =>
      card.imageUrl.startsWith('http://') ||
      card.imageUrl.startsWith('https://');
}
