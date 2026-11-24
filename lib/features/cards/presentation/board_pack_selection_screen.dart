import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/desi_buttons.dart';
import '../../../core/widgets/desi_states.dart';
import '../../../core/widgets/game_card_widget.dart';
import '../../../models/game_models.dart';
import '../../../shared/app_providers.dart';

class BoardPackSelectionScreen extends ConsumerStatefulWidget {
  const BoardPackSelectionScreen({
    super.key,
    required this.categoryName,
    this.mode = 'local',
    this.player1Name = 'Player 1',
    this.player2Name = 'Player 2',
  });

  final String categoryName;
  final String mode;
  final String player1Name;
  final String player2Name;

  @override
  ConsumerState<BoardPackSelectionScreen> createState() =>
      _BoardPackSelectionScreenState();
}

class _BoardPackSelectionScreenState
    extends ConsumerState<BoardPackSelectionScreen> {
  String _search = '';

  Future<void> _selectPack(BoardPack pack) async {
    if (!pack.meetsMinimumSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Add at least ${pack.category.minimumCards} cards to play this custom board.',
          ),
        ),
      );
      return;
    }

    if (FeatureFlags.enableOnlineMultiplayer && widget.mode == 'online') {
      context.push('/online/create?packId=${pack.packId}');
      return;
    }

    await ref
        .read(localMatchProvider.notifier)
        .startLocalMatch(
          pack: pack,
          player1Name: widget.player1Name,
          player2Name: widget.player2Name,
        );
    if (!mounted) return;
    context.push('/game/secret-select');
  }

  void _previewPackCards(BoardPack pack) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.92,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pack.name,
                          style: Theme.of(ctx).textTheme.titleLarge,
                        ),
                        Text(
                          '${pack.activeCards.length} cards • ${pack.category.displayName}',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: pack.activeCards.length,
                  itemBuilder: (_, idx) => GameCardWidget(
                    card: pack.activeCards[idx],
                    compact: true,
                    onTap: () {},
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DesiPrimaryButton(
                label: 'Play This Pack',
                icon: Icons.play_arrow_rounded,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _selectPack(pack);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = GameCategory.fromString(widget.categoryName);
    ref.watch(customBoardsProvider);
    final allPacks = ref
        .watch(cardRepositoryProvider)
        .packsForCategory(category);
    final packs = allPacks.where((p) {
      if (_search.trim().isEmpty) return true;
      final q = _search.toLowerCase();
      return p.name.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          p.cards.any((c) => c.name.toLowerCase().contains(q));
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text('${category.displayName} Packs')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: const InputDecoration(
                  hintText:
                      'Search packs or cards (e.g. Kohli, Biryani, Goa)...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: packs.isEmpty
                  ? DesiEmptyState(
                      icon: Icons.style_outlined,
                      title: 'No packs found',
                      subtitle: category == GameCategory.custom
                          ? 'Create your first custom board with your own cards!'
                          : 'Try another search keyword.',
                      actionLabel: category == GameCategory.custom
                          ? 'Create Custom Board'
                          : null,
                      onAction: category == GameCategory.custom
                          ? () => context.push('/custom-boards')
                          : null,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: packs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final pack = packs[idx];
                        final color = Color(pack.accentHex);
                        return DesiGlassCard(
                          borderColor: color.withValues(alpha: 0.45),
                          onTap: () => _selectPack(pack),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${pack.activeCards.length} CARDS',
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: () => _previewPackCards(pack),
                                    icon: const Icon(
                                      Icons.visibility_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('Preview'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pack.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pack.description,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
