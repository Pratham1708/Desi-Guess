import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/widgets/desi_buttons.dart';
import '../../../core/widgets/desi_states.dart';
import '../../../core/widgets/game_card_widget.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../models/game_models.dart';
import '../../../shared/app_providers.dart';

/// Secret Card Assignment & Reveal screen.
/// - For randomized 10-card matches (automatic secret assignment): privately reveals
///   each player's assigned secret card one at a time with Privacy Handoffs.
/// - For manual-pick custom decks: lets each player tap & lock a card from the grid.
class SecretCardSelectionScreen extends ConsumerStatefulWidget {
  const SecretCardSelectionScreen({super.key, this.roomId});

  final String? roomId;

  @override
  ConsumerState<SecretCardSelectionScreen> createState() =>
      _SecretCardSelectionScreenState();
}

class _SecretCardSelectionScreenState
    extends ConsumerState<SecretCardSelectionScreen> {
  String? _selectedCardId;
  String _search = '';
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    if (FeatureFlags.enableOnlineMultiplayer && widget.roomId != null) {
      return _buildOnlineSelector(context, widget.roomId!);
    }
    return _buildLocalSelector(context);
  }

  Widget _buildLocalSelector(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final match = ref.watch(localMatchProvider);
    if (match == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Secret Card')),
        body: DesiEmptyState(
          icon: Icons.style_outlined,
          title: 'No Active Match',
          subtitle:
              'Choose WHO, WHAT, or WHERE to generate a randomized 10-card board.',
          actionLabel: 'Choose Category',
          onAction: () => context.go('/categories'),
        ),
      );
    }

    if (match.requiresPrivacyHandoff) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/game/handoff');
      });
    }

    // Automatic Secret Assignment flow (both players already have distinct secrets assigned)
    final isAutoAssigned =
        match.player1.hasSelectedSecret && match.player2.hasSelectedSecret;
    if (isAutoAssigned) {
      final viewingPlayer = !match.player1.isReady
          ? match.player1
          : match.player2;
      final assignedCard = match.cardById(viewingPlayer.secretCardId);
      final isFirstPlayer = viewingPlayer.playerId == match.player1.playerId;

      return Scaffold(
        appBar: AppBar(
          title: Text('${viewingPlayer.displayName}\'s Secret Card'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: PlayerAvatar(
                    avatarId: viewingPlayer.avatarId,
                    size: 54,
                    isActiveTurn: true,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'ONLY ${viewingPlayer.displayName.toUpperCase()} SHOULD LOOK!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.saffronAccent,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your opponent must guess this secret card from the 10-card board.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: 240,
                      height: 310,
                      child: assignedCard != null
                          ? GameCardWidget(
                              card: assignedCard,
                              isMySecretCard: true,
                              onTap: () {},
                            )
                          : const DesiLoadingView(),
                    ),
                  ),
                ),
                if (assignedCard != null) ...[
                  const SizedBox(height: 12),
                  DesiGlassCard(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      assignedCard.description,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                DesiPrimaryButton(
                  label: isFirstPlayer
                      ? 'Hide & Pass to ${match.player2.displayName}'
                      : 'Hide & Start 10-Card Match!',
                  icon: Icons.visibility_off_rounded,
                  gradient: AppColors.saffronGradient,
                  isLoading: _submitting,
                  onPressed: () async {
                    setState(() => _submitting = true);
                    await ref
                        .read(localMatchProvider.notifier)
                        .acknowledgeAssignedSecret(viewingPlayer.playerId);
                    if (!mounted) return;
                    setState(() => _submitting = false);
                    if (!context.mounted) return;
                    context.go('/game/handoff');
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Legacy / Custom Board manual secret selection flow
    final choosingPlayer = !match.player1.hasSelectedSecret
        ? match.player1
        : match.player2;
    final cards = _filterCards(match.pack.activeCards);

    return _buildSelectionScaffold(
      context: context,
      title: '${choosingPlayer.displayName}: ${l10n.t('select_secret_card')}',
      subtitle: '${match.pack.name} • Pick the card your opponent must guess!',
      cards: cards,
      onConfirm: () async {
        if (_selectedCardId == null) return;
        setState(() => _submitting = true);
        await ref
            .read(localMatchProvider.notifier)
            .selectSecretCard(
              playerId: choosingPlayer.playerId,
              cardId: _selectedCardId!,
            );
        if (!mounted) return;
        setState(() {
          _submitting = false;
          _selectedCardId = null;
        });
        if (!context.mounted) return;
        context.go('/game/handoff');
      },
    );
  }

  Widget _buildOnlineSelector(BuildContext context, String roomId) {
    final roomAsync = ref.watch(roomStreamProvider(roomId));
    return roomAsync.when(
      loading: () => const Scaffold(
        body: DesiLoadingView(message: 'Loading online board...'),
      ),
      error: (e, _) => Scaffold(body: DesiErrorState(message: e.toString())),
      data: (room) {
        if (room == null) {
          return const Scaffold(
            body: DesiErrorState(message: 'Room not found or expired.'),
          );
        }
        if (room.status == MatchStatus.active) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/game/board?roomId=$roomId');
          });
        }
        final repo = ref.watch(cardRepositoryProvider);
        final pack = repo.buildBoardPackFromCardIds(
          category: room.category,
          cardIds: room.boardCardIds,
          customPackId: room.boardPackId,
        );
        if (pack == null) {
          return const Scaffold(
            body: DesiErrorState(message: 'Board pack could not be loaded.'),
          );
        }

        final cards = _filterCards(pack.activeCards);
        return _buildSelectionScaffold(
          context: context,
          title: 'Pick Your Secret Card',
          subtitle:
              '${pack.name} • Stored privately on server. Waiting for both players.',
          cards: cards,
          onConfirm: () async {
            if (_selectedCardId == null) return;
            setState(() => _submitting = true);
            try {
              await ref
                  .read(multiplayerRepositoryProvider)
                  .submitSecretSelection(
                    roomId: roomId,
                    secretCardId: _selectedCardId!,
                  );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Secret card locked! Waiting for opponent to lock theirs...',
                  ),
                ),
              );
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(e.toString())));
            } finally {
              if (mounted) setState(() => _submitting = false);
            }
          },
        );
      },
    );
  }

  List<GameCard> _filterCards(List<GameCard> all) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.description.toLowerCase().contains(q),
        )
        .toList();
  }

  Widget _buildSelectionScaffold({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<GameCard> cards,
    required Future<void> Function() onConfirm,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 600 ? 3 : 2;
    final selectedCard = cards
        .where((c) => c.id == _selectedCardId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: const InputDecoration(
                      hintText: 'Filter cards...',
                      prefixIcon: Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                  ),
                ],
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
                itemBuilder: (_, idx) {
                  final card = cards[idx];
                  return GameCardWidget(
                    card: card,
                    isSelected: _selectedCardId == card.id,
                    onTap: () => setState(() => _selectedCardId = card.id),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.secondaryBackground,
                border: Border(top: BorderSide(color: AppColors.borderSubtle)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selectedCard != null) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.saffronAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Selected: ${selectedCard.name}',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  DesiPrimaryButton(
                    label: selectedCard == null
                        ? 'Tap a Card to Select'
                        : 'Lock Secret Card',
                    icon: Icons.lock_rounded,
                    gradient: AppColors.saffronGradient,
                    isLoading: _submitting,
                    onPressed: _selectedCardId == null ? null : onConfirm,
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
