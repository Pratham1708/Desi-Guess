import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/desi_buttons.dart';
import '../../../core/widgets/desi_states.dart';
import '../../../core/widgets/game_card_widget.dart';
import '../../../shared/app_providers.dart';

/// Displays the freshly generated randomized 10-card board before secret card handoffs,
/// allowing players to inspect the mixed subcategories or re-roll a brand-new 10-card board.
class BoardPreviewScreen extends ConsumerWidget {
  const BoardPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final match = ref.watch(localMatchProvider);
    if (match == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('10-Card Board')),
        body: DesiEmptyState(
          icon: Icons.casino_outlined,
          title: 'No Board Generated',
          subtitle:
              'Pick WHO, WHAT, or WHERE to generate a randomized 10-card board.',
          actionLabel: 'Choose Category',
          onAction: () => context.go('/categories'),
        ),
      );
    }

    final cards = match.pack.activeCards;
    final subcategories = cards
        .map((c) => c.subcategory)
        .where((s) => s.isNotEmpty)
        .toSet();
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 600 ? 3 : 2;

    return Scaffold(
      appBar: AppBar(
        title: Text('${match.pack.category.displayName} • Random 10 Board'),
        actions: [
          IconButton(
            tooltip: 'Shuffle Fresh 10 Cards',
            onPressed: () async {
              final packs = ref
                  .read(cardRepositoryProvider)
                  .packsForCategory(match.pack.category);
              await ref
                  .read(localMatchProvider.notifier)
                  .startRandomizedLocalMatch(
                    category: match.pack.category,
                    sourcePacks: packs,
                    player1Name: match.player1.displayName,
                    player2Name: match.player2.displayName,
                  );
            },
            icon: const Icon(Icons.shuffle_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: DesiGlassCard(
                padding: const EdgeInsets.all(12),
                borderColor: AppColors.primaryAccent.withValues(alpha: 0.5),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.saffronAccent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${cards.length} Unique Cards • ${subcategories.length} Subcategories',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(color: Colors.white),
                          ),
                          Text(
                            'Both players share these 10 cards and receive 2 different secret cards.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.82,
                ),
                itemCount: cards.length,
                itemBuilder: (_, idx) =>
                    GameCardWidget(card: cards[idx], onTap: () {}),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.secondaryBackground,
                border: Border(top: BorderSide(color: AppColors.borderSubtle)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DesiSecondaryButton(
                      label: 'Re-Roll 10',
                      icon: Icons.shuffle_rounded,
                      onPressed: () async {
                        final packs = ref
                            .read(cardRepositoryProvider)
                            .packsForCategory(match.pack.category);
                        await ref
                            .read(localMatchProvider.notifier)
                            .startRandomizedLocalMatch(
                              category: match.pack.category,
                              sourcePacks: packs,
                              player1Name: match.player1.displayName,
                              player2Name: match.player2.displayName,
                            );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: DesiPrimaryButton(
                      label: 'Deal Secret Cards',
                      icon: Icons.lock_rounded,
                      gradient: AppColors.saffronGradient,
                      onPressed: () => context.go('/game/secret-select'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
