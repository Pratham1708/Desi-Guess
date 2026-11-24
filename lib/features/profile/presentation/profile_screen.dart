import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/desi_buttons.dart';
import '../../../core/widgets/desi_states.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../shared/app_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider);
    final profileRepo = ref.watch(profileRepositoryProvider);
    final history = ref.watch(matchHistoryProvider);
    final showOnline = FeatureFlags.enableOnlineMultiplayer;

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: DesiEmptyState(
          icon: Icons.person_outline_rounded,
          title: showOnline ? 'Sign In to View Profile' : 'Set Up Your Profile',
          subtitle: showOnline
              ? 'Create a Guest profile or sign in to track your stats.'
              : 'Pick a nickname and avatar to track your Pass-and-Play stats offline.',
          actionLabel: showOnline ? 'Sign In / Guest' : 'Create Local Profile',
          onAction: () => context.go(showOnline ? '/login' : '/guest-login'),
        ),
      );
    }

    final achievements = profileRepo.evaluateAchievements(profile);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Player Profile'),
        actions: [
          IconButton(
            tooltip: 'Edit Profile',
            onPressed: () => _openEditProfileDialog(context, ref),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Header Card
            DesiGlassCard(
              borderColor: AppColors.primaryAccent.withValues(alpha: 0.45),
              child: Row(
                children: [
                  PlayerAvatar(
                    avatarId: profile.avatarId,
                    size: 68,
                    isActiveTurn: true,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.username,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          profile.isGuest ? 'Guest Account' : profile.email,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.goldAccent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: Text(
                            'Rating ${profile.rating} • Best Streak ${profile.bestWinStreak}',
                            style: const TextStyle(
                              color: AppColors.goldAccent,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Stats Grid
            Row(
              children: [
                _MiniStat(
                  'Games',
                  '${profile.totalGames}',
                  AppColors.turquoiseAccent,
                ),
                const SizedBox(width: 10),
                _MiniStat('Wins', '${profile.wins}', AppColors.success),
                const SizedBox(width: 10),
                _MiniStat('Losses', '${profile.losses}', AppColors.danger),
                const SizedBox(width: 10),
                _MiniStat(
                  'Win %',
                  '${profile.winRate.toStringAsFixed(0)}%',
                  AppColors.saffronAccent,
                ),
              ],
            ),

            const SizedBox(height: 22),

            // Achievements
            Text('Achievements', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            ...achievements.map((a) {
              final color = Color(a.accentHex);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DesiGlassCard(
                  padding: const EdgeInsets.all(12),
                  borderColor: a.isUnlocked
                      ? color.withValues(alpha: 0.65)
                      : AppColors.borderSubtle,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (a.isUnlocked ? color : AppColors.textMuted)
                              .withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          a.isUnlocked
                              ? Icons.workspace_premium_rounded
                              : Icons.lock_outline_rounded,
                          color: a.isUnlocked ? color : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.title,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: a.isUnlocked
                                        ? Colors.white
                                        : AppColors.textMuted,
                                  ),
                            ),
                            Text(
                              a.description,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (a.isUnlocked)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 18),

            // Recent Match History
            Text(
              'Recent Matches',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            if (history.isEmpty)
              DesiGlassCard(
                child: Text(
                  showOnline
                      ? 'Complete a Local or Online match to see your match log here.'
                      : 'Complete a Pass-and-Play match to see your match log here.',
                ),
              )
            else
              ...history
                  .take(8)
                  .map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: DesiGlassCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.emoji_events_rounded,
                              color: AppColors.goldAccent,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${m.winnerName} beat ${m.loserName}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  Text(
                                    '${m.packName} • ${m.winReason}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${m.winnerHeartsRemaining} ♥',
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

            if (FeatureFlags.enableOnlineInvites) ...[
              const SizedBox(height: 16),
              DesiSecondaryButton(
                label: 'Friends & Invites',
                icon: Icons.group_add_rounded,
                onPressed: () => context.push('/friends'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final profile = ref.read(authProvider);
    if (profile == null) return;
    final nameCtrl = TextEditingController(text: profile.username);
    var avatar = profile.avatarId;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Edit Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: PlayerAvatar.presets.map((p) {
                  return GestureDetector(
                    onTap: () => setState(() => avatar = p.id),
                    child: PlayerAvatar(
                      avatarId: p.id,
                      size: 42,
                      isActiveTurn: avatar == p.id,
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
                if (nameCtrl.text.trim().isNotEmpty) {
                  await ref
                      .read(authProvider.notifier)
                      .updateProfile(
                        username: nameCtrl.text.trim(),
                        avatarId: avatar,
                      );
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DesiGlassCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
