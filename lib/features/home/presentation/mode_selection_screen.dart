import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/desi_buttons.dart';
import '../../../core/widgets/desi_states.dart';
import '../../../shared/app_providers.dart';

/// Game Mode Selection screen (Online Multiplayer vs Face-to-Face Local Multiplayer).
class ModeSelectionScreen extends ConsumerStatefulWidget {
  const ModeSelectionScreen({
    super.key,
    this.initialFocus,
    this.preselectedPackId,
  });

  final String? initialFocus;
  final String? preselectedPackId;

  @override
  ConsumerState<ModeSelectionScreen> createState() =>
      _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends ConsumerState<ModeSelectionScreen> {
  late final TextEditingController _p1Controller;
  late final TextEditingController _p2Controller;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authProvider);
    _p1Controller = TextEditingController(
      text: profile?.username ?? 'Player 1',
    );
    _p2Controller = TextEditingController(text: 'Player 2');
  }

  @override
  void dispose() {
    _p1Controller.dispose();
    _p2Controller.dispose();
    super.dispose();
  }

  Future<void> _startLocalWithPack(String packId) async {
    final pack = ref.read(cardRepositoryProvider).findPackById(packId);
    if (pack == null) return;
    await ref
        .read(localMatchProvider.notifier)
        .startLocalMatch(
          pack: pack,
          player1Name: _p1Controller.text,
          player2Name: _p2Controller.text,
        );
    if (!mounted) return;
    context.push('/game/secret-select');
  }

  @override
  Widget build(BuildContext context) {
    final showOnline = FeatureFlags.enableOnlineMultiplayer;
    final preselectedPack = widget.preselectedPackId != null
        ? ref
              .watch(cardRepositoryProvider)
              .findPackById(widget.preselectedPackId!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(showOnline ? 'Choose Game Mode' : 'Pass & Play Setup'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            if (preselectedPack != null) ...[
              DesiGlassCard(
                borderColor: AppColors.saffronAccent.withValues(alpha: 0.6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.style_rounded,
                      color: AppColors.saffronAccent,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected Pack: ${preselectedPack.name}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${preselectedPack.category.displayName} • ${preselectedPack.activeCards.length} playable cards',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Mode A: Local Pass & Play
            DesiGlassCard(
              borderColor: AppColors.saffronAccent.withValues(alpha: 0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: AppColors.saffronGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.people_alt_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Face-to-Face / Local',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              'Two players on one phone • Works offline',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _p1Controller,
                          decoration: const InputDecoration(
                            labelText: 'Player 1 Name',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _p2Controller,
                          decoration: const InputDecoration(
                            labelText: 'Player 2 Name',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DesiPrimaryButton(
                    label: preselectedPack != null
                        ? 'Start Local Match Now'
                        : 'Select Category & Play Local',
                    icon: Icons.play_arrow_rounded,
                    gradient: AppColors.saffronGradient,
                    onPressed: () {
                      if (preselectedPack != null) {
                        _startLocalWithPack(preselectedPack.packId);
                      } else {
                        final p1 = Uri.encodeComponent(
                          _p1Controller.text.trim(),
                        );
                        final p2 = Uri.encodeComponent(
                          _p2Controller.text.trim(),
                        );
                        context.push('/categories?mode=local&p1=$p1&p2=$p2');
                      }
                    },
                  ),
                ],
              ),
            ),

            if (showOnline) ...[
              const SizedBox(height: AppSpacing.md),

              // Mode B: Online Multiplayer (preserved for future release)
              DesiGlassCard(
                borderColor: AppColors.primaryAccent.withValues(alpha: 0.55),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryButtonGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.public_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Online Multiplayer',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(
                                '6-letter room code • Real-time chat & sync',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DesiPrimaryButton(
                            label: 'Create Room',
                            icon: Icons.add_box_rounded,
                            onPressed: () => context.push(
                              preselectedPack != null
                                  ? '/online/create?packId=${preselectedPack.packId}'
                                  : '/online/create',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DesiSecondaryButton(
                            label: 'Join Room',
                            icon: Icons.meeting_room_rounded,
                            onPressed: () => context.push('/online/join'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              DesiGlassCard(
                onTap: () => context.push('/friends'),
                child: const Row(
                  children: [
                    Icon(
                      Icons.group_add_rounded,
                      color: AppColors.turquoiseAccent,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Invite Friends & Send Room Codes',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
