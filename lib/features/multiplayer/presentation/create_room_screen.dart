import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/desi_buttons.dart';
import '../../../core/widgets/desi_states.dart';
import '../../../models/game_models.dart';
import '../../../shared/app_providers.dart';

/// Streamlined Create Online Room screen:
/// Players select only WHO, WHAT, or WHERE (all subcategories participate in
/// backend randomized 10-card board generation), or optionally a shared Custom Board.
class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key, this.initialPackId, this.initialCategory});

  final String? initialPackId;
  final String? initialCategory;

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  GameCategory _category = GameCategory.who;
  String? _selectedCustomBoardId;
  int? _turnTimerSeconds = 60;
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _category = GameCategory.fromString(widget.initialCategory!);
    }
    if (widget.initialPackId != null) {
      final pack = ref
          .read(cardRepositoryProvider)
          .findPackById(widget.initialPackId!);
      if (pack != null) {
        _category = pack.category;
        if (pack.category == GameCategory.custom) {
          _selectedCustomBoardId = pack.packId;
        }
      }
    }
  }

  Future<void> _createRoom() async {
    final boardPackId = _category == GameCategory.custom
        ? (_selectedCustomBoardId ?? '')
        : 'random_${_category.name}';
    if (_category == GameCategory.custom && boardPackId.isEmpty) {
      setState(() => _error = 'Select a shared custom board first.');
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final created = await ref
          .read(multiplayerRepositoryProvider)
          .createRoom(
            category: _category,
            boardPackId: boardPackId,
            turnTimerSeconds: _turnTimerSeconds,
          );
      if (!mounted) return;
      context.go('/online/lobby/${created.roomId}');
    } on AppFailure catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mpReady = ref.watch(multiplayerRepositoryProvider).isAvailable;
    final customBoards = ref
        .watch(customBoardsProvider)
        .where((b) => b.meetsMinimumSize)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Create Online Room')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            if (!mpReady) ...[
              DesiGlassCard(
                borderColor: AppColors.saffronAccent.withValues(alpha: 0.6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          color: AppColors.saffronAccent,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Online Multiplayer Disabled in Local Mode',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.saffronAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      FirebaseService.instance.unavailableReason,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    const SizedBox(height: 10),
                    DesiSecondaryButton(
                      label: 'Play Local 10-Card Offline Instead',
                      height: 42,
                      onPressed: () => context.go('/play?focus=local'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              '1. Select Main Category',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            SegmentedButton<GameCategory>(
              segments: const [
                ButtonSegment(value: GameCategory.who, label: Text('WHO')),
                ButtonSegment(value: GameCategory.what, label: Text('WHAT')),
                ButtonSegment(value: GameCategory.where, label: Text('WHERE')),
                ButtonSegment(
                  value: GameCategory.custom,
                  label: Text('CUSTOM'),
                ),
              ],
              selected: {_category},
              onSelectionChanged: (sel) {
                setState(() {
                  _category = sel.first;
                  if (_category == GameCategory.custom &&
                      customBoards.isNotEmpty) {
                    _selectedCustomBoardId ??= customBoards.first.packId;
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            if (_category != GameCategory.custom)
              DesiGlassCard(
                borderColor: AppColors.turquoiseAccent.withValues(alpha: 0.45),
                child: Row(
                  children: [
                    const Icon(
                      Icons.casino_rounded,
                      color: AppColors.turquoiseAccent,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Randomized 10-Card ${_category.displayName} Board',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Server automatically generates a balanced 10-card board across all ${_category.displayName} subcategories and deals 2 distinct secret cards.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Text(
                'Choose Your Custom Board',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (customBoards.isEmpty)
                DesiGlassCard(
                  onTap: () => context.push('/custom-boards'),
                  child: const Text(
                    'No playable custom boards yet (need 6+ cards). Tap here to create one!',
                  ),
                )
              else
                ...customBoards.map((board) {
                  final selected = board.packId == _selectedCustomBoardId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: DesiGlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      borderColor: selected
                          ? AppColors.saffronAccent
                          : AppColors.borderSubtle,
                      onTap: () =>
                          setState(() => _selectedCustomBoardId = board.packId),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  board.name,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(color: Colors.white),
                                ),
                                Text(
                                  '${board.activeCards.length} cards • ${board.isShared ? 'Shared' : 'Set to Shared to invite'}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            selected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            color: selected
                                ? AppColors.saffronAccent
                                : AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
            const SizedBox(height: 20),
            Text(
              '2. Optional Turn Timer',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [null, 30, 60, 90].map((sec) {
                return ChoiceChip(
                  label: Text(sec == null ? 'No Limit' : '${sec}s'),
                  selected: _turnTimerSeconds == sec,
                  onSelected: (_) => setState(() => _turnTimerSeconds = sec),
                );
              }).toList(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 24),
            DesiPrimaryButton(
              label: 'Create Room & Get Code',
              icon: Icons.add_box_rounded,
              isLoading: _creating,
              onPressed: _createRoom,
            ),
          ],
        ),
      ),
    );
  }
}
