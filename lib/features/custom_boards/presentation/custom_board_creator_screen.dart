import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/desi_buttons.dart';
import '../../../core/widgets/desi_states.dart';
import '../../../models/game_models.dart';
import '../../../shared/app_providers.dart';

/// Custom Board Creator screen — create, sync with Firebase, share by 6-char code,
/// join friends' shared boards, manage cards, and launch local or online matches.
class CustomBoardCreatorScreen extends ConsumerWidget {
  const CustomBoardCreatorScreen({super.key});

  static const List<int> _palette = [
    0xFF8B5CF6,
    0xFFFF9933,
    0xFF2DD4BF,
    0xFFEC4899,
    0xFF22C55E,
    0xFF3B82F6,
  ];

  Future<void> _showCreateBoardDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    int selectedColor = _palette.first;
    var visibility = BoardVisibility.private;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('New Custom Board'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Board Title',
                  hintText: 'e.g., College Squad, Family Inside Jokes',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Short Description',
                ),
              ),
              if (FeatureFlags.enableOnlineMultiplayer) ...[
                const SizedBox(height: 12),
                SegmentedButton<BoardVisibility>(
                  segments: const [
                    ButtonSegment(
                      value: BoardVisibility.private,
                      label: Text('Private'),
                      icon: Icon(Icons.lock_outline_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: BoardVisibility.shared,
                      label: Text('Shared'),
                      icon: Icon(Icons.share_rounded, size: 16),
                    ),
                  ],
                  selected: {visibility},
                  onSelectionChanged: (sel) =>
                      setState(() => visibility = sel.first),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _palette.map((hex) {
                  final active = selectedColor == hex;
                  return GestureDetector(
                    onTap: () => setState(() => selectedColor = hex),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Color(hex),
                        shape: BoxShape.circle,
                        border: active
                            ? Border.all(color: Colors.white, width: 2.5)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final owner = ref.read(authProvider)?.uid;
                final created = await ref
                    .read(customBoardsProvider.notifier)
                    .createBoard(
                      name: nameCtrl.text,
                      description: descCtrl.text,
                      accentHex: selectedColor,
                      ownerUid: owner,
                      visibility: visibility,
                    );
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                if (context.mounted) {
                  context.push('/custom-boards/${created.packId}/cards/new');
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    descCtrl.dispose();
  }

  Future<void> _showJoinByCodeDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final codeCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join Shared Board'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the 6-character share code from a friend to sync their shared custom board.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: '6-Char Share Code',
                hintText: 'K9P4M2',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final code = codeCtrl.text.trim().toUpperCase();
              Navigator.of(ctx).pop();
              try {
                final board = await ref
                    .read(customBoardsProvider.notifier)
                    .joinByShareCode(code);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Synced "${board.name}"!')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Join Board'),
          ),
        ],
      ),
    );
    codeCtrl.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boards = ref.watch(customBoardsProvider);
    final myUid = ref.watch(authProvider)?.uid;
    final showOnline = FeatureFlags.enableOnlineMultiplayer;
    final cloudReady =
        showOnline &&
        ref.watch(customBoardRepositoryProvider).isCloudSyncAvailable;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Boards'),
        actions: [
          if (showOnline)
            IconButton(
              tooltip: 'Join Shared Board by Code',
              onPressed: () => _showJoinByCodeDialog(context, ref),
              icon: const Icon(Icons.qr_code_rounded),
            ),
          if (cloudReady)
            IconButton(
              tooltip: 'Sync from Cloud',
              onPressed: () =>
                  ref.read(customBoardsProvider.notifier).syncFromCloud(),
              icon: const Icon(Icons.cloud_sync_rounded),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryAccent,
        foregroundColor: Colors.white,
        onPressed: () => _showCreateBoardDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Board'),
      ),
      body: SafeArea(
        child: boards.isEmpty
            ? DesiEmptyState(
                icon: Icons.dashboard_customize_rounded,
                title: 'Create Your Own Desi Deck',
                subtitle: showOnline
                    ? 'Build private or shared guessing boards for friends, college squads, or family — synced offline & in the cloud!'
                    : 'Build your own custom guessing boards for friends, college squads, or family — saved offline for Pass-and-Play!',
                actionLabel: 'Create First Board',
                onAction: () => _showCreateBoardDialog(context, ref),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                itemCount: boards.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, idx) {
                  final board = boards[idx];
                  final color = Color(board.accentHex);
                  final playable = board.meetsMinimumSize;
                  final isOwner =
                      board.ownerUid == null || board.ownerUid == myUid;

                  return DesiGlassCard(
                    borderColor: color.withValues(alpha: 0.55),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          board.name,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              (board.isShared
                                                      ? AppColors
                                                            .turquoiseAccent
                                                      : AppColors.textMuted)
                                                  .withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(
                                            AppRadii.pill,
                                          ),
                                        ),
                                        child: Text(
                                          board.isShared ? 'SHARED' : 'PRIVATE',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: board.isShared
                                                ? AppColors.turquoiseAccent
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${board.activeCards.length} cards • '
                                    '${playable ? 'Ready to Play' : 'Add ${GameCategory.custom.minimumCards - board.activeCards.length} more to play'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: playable
                                          ? AppColors.success
                                          : AppColors.saffronAccent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isOwner) ...[
                              if (showOnline)
                                IconButton(
                                  tooltip: board.isShared
                                      ? 'Make Private'
                                      : 'Share Board',
                                  onPressed: () async {
                                    final nextVis = board.isShared
                                        ? BoardVisibility.private
                                        : BoardVisibility.shared;
                                    final updated = await ref
                                        .read(customBoardsProvider.notifier)
                                        .toggleSharing(
                                          boardId: board.packId,
                                          visibility: nextVis,
                                        );
                                    if (!context.mounted || updated == null) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          updated.isShared
                                              ? 'Board shared! Code: ${updated.shareCode}'
                                              : 'Board is now private.',
                                        ),
                                      ),
                                    );
                                  },
                                  icon: Icon(
                                    board.isShared
                                        ? Icons.public_rounded
                                        : Icons.lock_outline_rounded,
                                    color: board.isShared
                                        ? AppColors.turquoiseAccent
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              IconButton(
                                tooltip: 'Delete Board',
                                onPressed: () async {
                                  final ok = await showDesiConfirmDialog(
                                    context,
                                    title: 'Delete "${board.name}"?',
                                    message:
                                        'This removes the board and its custom cards.',
                                    confirmLabel: 'Delete',
                                    isDestructive: true,
                                  );
                                  if (ok) {
                                    await ref
                                        .read(customBoardsProvider.notifier)
                                        .deleteBoard(board.packId);
                                  }
                                },
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.danger,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          board.description,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (showOnline &&
                            board.isShared &&
                            board.shareCode != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBackground,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.turquoiseAccent.withValues(
                                      alpha: 0.45,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Share Code: ${board.shareCode}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: AppColors.turquoiseAccent,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                tooltip: 'Copy Share Code',
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: board.shareCode!),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Share code copied!'),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.share_rounded, size: 18),
                                tooltip: 'Invite Friends',
                                onPressed: () {
                                  Share.share(
                                    'Play my custom DESI GUESS board "${board.name}"! Share Code: ${board.shareCode}',
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                        if (board.cards.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: board.cards
                                .take(8)
                                .map(
                                  (c) => Chip(
                                    label: Text(c.name),
                                    visualDensity: VisualDensity.compact,
                                    onDeleted: isOwner
                                        ? () => ref
                                              .read(
                                                customBoardsProvider.notifier,
                                              )
                                              .removeCardFromBoard(
                                                boardId: board.packId,
                                                cardId: c.id,
                                              )
                                        : null,
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            if (isOwner) ...[
                              Expanded(
                                child: DesiSecondaryButton(
                                  label: 'Add Card',
                                  icon: Icons.add_card_rounded,
                                  height: 42,
                                  onPressed: () => context.push(
                                    '/custom-boards/${board.packId}/cards/new',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: DesiPrimaryButton(
                                label: 'Play Local',
                                icon: Icons.play_arrow_rounded,
                                height: 42,
                                onPressed: playable
                                    ? () => context.push(
                                        '/play?focus=local&packId=${board.packId}',
                                      )
                                    : null,
                              ),
                            ),
                            if (showOnline && board.isShared && playable) ...[
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                tooltip: 'Host Online Room',
                                onPressed: () => context.push(
                                  '/online/create?packId=${board.packId}',
                                ),
                                icon: const Icon(Icons.public_rounded),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
