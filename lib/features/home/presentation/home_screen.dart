import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/widgets/desi_buttons.dart';
import '../../../core/widgets/desi_logo.dart';
import '../../../core/widgets/desi_states.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../models/game_models.dart';
import '../../../shared/app_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(authProvider);
    final cardRepo = ref.watch(cardRepositoryProvider);
    final activeLocalMatch = ref.watch(localMatchProvider);
    final showOnline = FeatureFlags.enableOnlineMultiplayer;
    final showLeaderboard = FeatureFlags.enableOnlineLeaderboard;
    final leaderboardAsync = showLeaderboard
        ? ref.watch(leaderboardProvider)
        : null;
    final audio = ref.read(audioServiceProvider);

    final recentPacks = cardRepo.recentPacks();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Top bar: Logo + Avatar + Profile + Settings
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: DesiLogo(size: 38),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Help & Rules',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => context.push('/help'),
                      icon: const Icon(Icons.help_outline_rounded),
                    ),
                    IconButton(
                      tooltip: 'Settings',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => context.push('/settings'),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => context.push('/profile'),
                      child: PlayerAvatar(
                        avatarId: profile?.avatarId ?? 'avatar_1',
                        size: 36,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.md),
              sliver: SliverList.list(
                children: [
                  // Resume Local Match Banner if persisted
                  if (activeLocalMatch != null &&
                      !activeLocalMatch.isCompleted) ...[
                    DesiGlassCard(
                      borderColor: AppColors.turquoiseAccent.withValues(
                        alpha: 0.7,
                      ),
                      onTap: () {
                        if (activeLocalMatch.status ==
                            MatchStatus.selectingSecrets) {
                          context.push('/game/secret-select');
                        } else if (activeLocalMatch.requiresPrivacyHandoff) {
                          context.push('/game/handoff');
                        } else {
                          context.push('/game/board');
                        }
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.turquoiseAccent.withValues(
                                alpha: 0.2,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_circle_fill_rounded,
                              color: AppColors.turquoiseAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.t('resume_match'),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text(
                                  '${activeLocalMatch.pack.name} • Turn ${activeLocalMatch.turnNumber}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.turquoiseAccent,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Main Hero Card
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      gradient: AppColors.heroGradient,
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                      border: Border.all(
                        color: AppColors.secondaryAccent.withValues(
                          alpha: 0.35,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryAccent.withValues(alpha: 0.2),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.saffronAccent.withValues(
                              alpha: 0.2,
                            ),
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            border: Border.all(
                              color: AppColors.saffronAccent.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          child: Text(
                            showOnline
                                ? 'NAMASTE • 2-PLAYER DEDUCTION'
                                : 'PASS & PLAY • 2-PLAYER OFFLINE',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: AppColors.saffronAccent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          l10n.t('hero_headline'),
                          style: Theme.of(
                            context,
                          ).textTheme.headlineMedium?.copyWith(height: 1.15),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          showOnline
                              ? l10n.t('hero_subtitle')
                              : l10n.t('play_together_sub'),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        if (showOnline)
                          Row(
                            children: [
                              Expanded(
                                child: DesiPrimaryButton(
                                  label: l10n.t('play_online'),
                                  icon: Icons.public_rounded,
                                  onPressed: () {
                                    audio.play(GameSfx.buttonTap);
                                    context.push('/play?focus=online');
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DesiPrimaryButton(
                                  label: l10n.t('play_together'),
                                  icon: Icons.people_alt_rounded,
                                  gradient: AppColors.saffronGradient,
                                  onPressed: () {
                                    audio.play(GameSfx.buttonTap);
                                    context.push('/play?focus=local');
                                  },
                                ),
                              ),
                            ],
                          )
                        else
                          DesiPrimaryButton(
                            label: l10n.t('play_together'),
                            icon: Icons.people_alt_rounded,
                            gradient: AppColors.saffronGradient,
                            onPressed: () {
                              audio.play(GameSfx.buttonTap);
                              context.push('/play?focus=local');
                            },
                          ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.06),

                  const SizedBox(height: AppSpacing.lg),

                  // Player Stats Strip
                  _SectionHeader(
                    title: l10n.t('your_stats'),
                    actionLabel: 'Profile',
                    onAction: () => context.push('/profile'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _StatTile(
                        label: 'Rating',
                        value: '${profile?.rating ?? 1000}',
                        accent: AppColors.goldAccent,
                        icon: Icons.military_tech_rounded,
                      ),
                      const SizedBox(width: 10),
                      _StatTile(
                        label: 'Wins',
                        value: '${profile?.wins ?? 0}',
                        accent: AppColors.success,
                        icon: Icons.emoji_events_rounded,
                      ),
                      const SizedBox(width: 10),
                      _StatTile(
                        label: 'Matches',
                        value: '${profile?.totalGames ?? 0}',
                        accent: AppColors.turquoiseAccent,
                        icon: Icons.sports_esports_rounded,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Featured Categories
                  _SectionHeader(
                    title: l10n.t('featured_categories'),
                    actionLabel: l10n.t('see_all'),
                    onAction: () => context.push('/categories'),
                  ),
                  const SizedBox(height: 10),
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 122,
                        ),
                    children: [
                      _CategoryTile(
                        title: l10n.t('cat_who'),
                        subtitle: 'Random 10 • 250 Cards',
                        icon: Icons.person_search_rounded,
                        color: AppColors.primaryAccent,
                        onTap: () async {
                          final packs = cardRepo.packsForCategory(
                            GameCategory.who,
                          );
                          await ref
                              .read(localMatchProvider.notifier)
                              .startRandomizedLocalMatch(
                                category: GameCategory.who,
                                sourcePacks: packs,
                                player1Name: profile?.username ?? 'Player 1',
                                player2Name: 'Player 2',
                              );
                          if (!context.mounted) return;
                          context.push('/game/preview');
                        },
                      ),
                      _CategoryTile(
                        title: l10n.t('cat_what'),
                        subtitle: 'Random 10 • 128 Cards',
                        icon: Icons.fastfood_rounded,
                        color: AppColors.saffronAccent,
                        onTap: () async {
                          final packs = cardRepo.packsForCategory(
                            GameCategory.what,
                          );
                          await ref
                              .read(localMatchProvider.notifier)
                              .startRandomizedLocalMatch(
                                category: GameCategory.what,
                                sourcePacks: packs,
                                player1Name: profile?.username ?? 'Player 1',
                                player2Name: 'Player 2',
                              );
                          if (!context.mounted) return;
                          context.push('/game/preview');
                        },
                      ),
                      _CategoryTile(
                        title: l10n.t('cat_where'),
                        subtitle: 'Random 10 • 72 Cards',
                        icon: Icons.explore_rounded,
                        color: AppColors.turquoiseAccent,
                        onTap: () async {
                          final packs = cardRepo.packsForCategory(
                            GameCategory.where,
                          );
                          await ref
                              .read(localMatchProvider.notifier)
                              .startRandomizedLocalMatch(
                                category: GameCategory.where,
                                sourcePacks: packs,
                                player1Name: profile?.username ?? 'Player 1',
                                player2Name: 'Player 2',
                              );
                          if (!context.mounted) return;
                          context.push('/game/preview');
                        },
                      ),
                      _CategoryTile(
                        title: l10n.t('cat_custom'),
                        subtitle: 'Build Your Own',
                        icon: Icons.auto_awesome_rounded,
                        color: const Color(0xFFEC4899),
                        onTap: () => context.push('/custom-boards'),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Daily Challenge
                  DesiGlassCard(
                    borderColor: AppColors.goldAccent.withValues(alpha: 0.45),
                    onTap: () => context.push(
                      '/play?focus=local&packId=who_bollywood_actors',
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: AppColors.saffronGradient,
                          ),
                          child: const Icon(
                            Icons.local_fire_department_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.t('daily_challenge'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.t('daily_challenge_sub'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: AppColors.saffronAccent,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Recently Played Packs
                  _SectionHeader(
                    title: l10n.t('recently_played'),
                    actionLabel: l10n.t('see_all'),
                    onAction: () => context.push('/categories'),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 132,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: recentPacks.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, idx) {
                        final pack = recentPacks[idx];
                        final color = Color(pack.accentHex);
                        return SizedBox(
                          width: 190,
                          child: DesiGlassCard(
                            padding: const EdgeInsets.all(12),
                            borderColor: color.withValues(alpha: 0.45),
                            onTap: () => context.push(
                              '/play?focus=local&packId=${pack.packId}',
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        pack.category.displayName,
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${pack.activeCards.length} cards',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pack.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      pack.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  if (showLeaderboard && leaderboardAsync != null) ...[
                    const SizedBox(height: AppSpacing.lg),

                    // Leaderboard Preview
                    _SectionHeader(
                      title: l10n.t('leaderboard_preview'),
                      actionLabel: l10n.t('see_all'),
                      onAction: () => context.push('/leaderboard'),
                    ),
                    const SizedBox(height: 10),
                    leaderboardAsync.when(
                      data: (entries) {
                        if (entries.isEmpty) {
                          return DesiGlassCard(
                            onTap: () => context.push('/leaderboard'),
                            child: const Text(
                              'Play a match or sign in to appear on the Desi Guess Leaderboard!',
                            ),
                          );
                        }
                        final top = entries.take(3).toList();
                        return DesiGlassCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Column(
                            children: top
                                .map(
                                  (e) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppColors.primaryAccent
                                          .withValues(alpha: 0.25),
                                      child: Text(
                                        '#${e.rank}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.secondaryAccent,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      e.username,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    subtitle: Text('${e.wins} wins'),
                                    trailing: Text(
                                      '${e.rating} pts',
                                      style: const TextStyle(
                                        color: AppColors.goldAccent,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        );
                      },
                      loading: () => const DesiLoadingView(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.secondaryBackground,
        indicatorColor: AppColors.primaryAccent.withValues(alpha: 0.22),
        selectedIndex: 0,
        onDestinationSelected: (idx) {
          if (showLeaderboard) {
            switch (idx) {
              case 0:
                break;
              case 1:
                context.push('/play');
              case 2:
                context.push('/custom-boards');
              case 3:
                context.push('/leaderboard');
              case 4:
                context.push('/profile');
            }
          } else {
            switch (idx) {
              case 0:
                break;
              case 1:
                context.push('/play');
              case 2:
                context.push('/custom-boards');
              case 3:
                context.push('/profile');
            }
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: l10n.t('nav_home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.sports_esports_outlined),
            selectedIcon: const Icon(Icons.sports_esports_rounded),
            label: l10n.t('nav_play'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.dashboard_customize_outlined),
            selectedIcon: const Icon(Icons.dashboard_customize_rounded),
            label: l10n.t('nav_boards'),
          ),
          if (showLeaderboard)
            NavigationDestination(
              icon: const Icon(Icons.leaderboard_outlined),
              selectedIcon: const Icon(Icons.leaderboard_rounded),
              label: l10n.t('nav_ranks'),
            ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: l10n.t('nav_profile'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onAction,
          child: Text(
            actionLabel,
            style: const TextStyle(
              color: AppColors.secondaryAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
  });

  final String label;
  final String value;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DesiGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DesiGlassCard(
      padding: const EdgeInsets.all(12),
      borderColor: color.withValues(alpha: 0.45),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
