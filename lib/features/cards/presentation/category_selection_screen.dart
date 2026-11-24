import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/card_artwork_resolver.dart';
import '../../../core/widgets/desi_states.dart';
import '../../../models/game_models.dart';
import '../../../shared/app_providers.dart';

/// Main Category Selection: WHO, WHAT, or WHERE.
/// Players NEVER need to manually choose a subcategory before a normal match —
/// all active subcategories participate automatically in generating a fresh 10-card board!
class CategorySelectionScreen extends ConsumerWidget {
  const CategorySelectionScreen({
    super.key,
    this.mode = 'local',
    this.player1Name = 'Player 1',
    this.player2Name = 'Player 2',
  });

  final String mode;
  final String player1Name;
  final String player2Name;

  Future<void> _launchCategory(
    BuildContext context,
    WidgetRef ref,
    GameCategory category,
  ) async {
    if (FeatureFlags.enableOnlineMultiplayer && mode == 'online') {
      context.push('/online/create?category=${category.name}');
      return;
    }

    final packs = ref.read(cardRepositoryProvider).packsForCategory(category);
    try {
      await ref
          .read(localMatchProvider.notifier)
          .startRandomizedLocalMatch(
            category: category,
            sourcePacks: packs,
            player1Name: player1Name,
            player2Name: player2Name,
          );
      if (!context.mounted) return;
      context.push('/game/preview');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repo = ref.watch(cardRepositoryProvider);
    final customCount = ref.watch(customBoardsProvider).length;

    final primaryCategories = [
      (
        cat: GameCategory.who,
        title: l10n.t('cat_who'),
        desc:
            '10-card random mix across Bollywood, Cricket, Singers, Influencers, Politicians, TV, Cartoons, Sports & Memes.',
        cardCount: repo
            .packsForCategory(GameCategory.who)
            .fold<int>(0, (s, p) => s + p.activeCards.length),
        subCount: repo.packsForCategory(GameCategory.who).length,
        art: CardArtworkResolver.fallbackWho,
        color: AppColors.primaryAccent,
      ),
      (
        cat: GameCategory.what,
        title: l10n.t('cat_what'),
        desc:
            '10-card random mix across Indian Food, Snacks, Brands, Vehicles, Movies, Household, Tech & Products.',
        cardCount: repo
            .packsForCategory(GameCategory.what)
            .fold<int>(0, (s, p) => s + p.activeCards.length),
        subCount: repo.packsForCategory(GameCategory.what).length,
        art: CardArtworkResolver.fallbackWhat,
        color: AppColors.saffronAccent,
      ),
      (
        cat: GameCategory.where,
        title: l10n.t('cat_where'),
        desc:
            '10-card random mix across Indian Cities, States, Monuments, Attractions, Colleges & Destinations.',
        cardCount: repo
            .packsForCategory(GameCategory.where)
            .fold<int>(0, (s, p) => s + p.activeCards.length),
        subCount: repo.packsForCategory(GameCategory.where).length,
        art: CardArtworkResolver.fallbackWhere,
        color: AppColors.turquoiseAccent,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Choose WHO, WHAT or WHERE')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              'Every match deals 10 freshly randomized cards mixed across all subcategories.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            ...primaryCategories.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: DesiGlassCard(
                  padding: const EdgeInsets.all(14),
                  borderColor: item.color.withValues(alpha: 0.55),
                  onTap: () => _launchCategory(context, ref, item.cat),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 78,
                          height: 78,
                          child: Image.asset(
                            item.art,
                            fit: BoxFit.cover,
                            cacheWidth: 200,
                            errorBuilder: (_, _, _) => Container(
                              color: item.color.withValues(alpha: 0.2),
                              child: Icon(
                                Icons.casino_rounded,
                                color: item.color,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  item.title,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: item.color.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.pill,
                                    ),
                                  ),
                                  child: Text(
                                    '${item.cardCount} cards • ${item.subCount} themes',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: item.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.desc,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.play_circle_fill_rounded,
                        color: item.color,
                        size: 30,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 28),
            DesiGlassCard(
              borderColor: const Color(0xFFEC4899).withValues(alpha: 0.45),
              onTap: () => context.push('/custom-boards'),
              child: Row(
                children: [
                  const Icon(
                    Icons.dashboard_customize_rounded,
                    color: Color(0xFFEC4899),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Play or Create Custom Boards',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '$customCount custom boards available',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
