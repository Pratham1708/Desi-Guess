import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/desi_states.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../shared/app_providers.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeframe = ref.watch(leaderboardTimeframeProvider);
    final entriesAsync = ref.watch(leaderboardProvider);
    final myUid = ref.watch(authProvider)?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'daily', label: Text('Daily')),
                  ButtonSegment(value: 'weekly', label: Text('Weekly')),
                  ButtonSegment(value: 'all_time', label: Text('All-Time')),
                ],
                selected: {timeframe},
                onSelectionChanged: (sel) =>
                    ref.read(leaderboardTimeframeProvider.notifier).state =
                        sel.first,
              ),
            ),
            Expanded(
              child: entriesAsync.when(
                loading: () =>
                    const DesiLoadingView(message: 'Loading rankings...'),
                error: (e, _) => DesiErrorState(message: e.toString()),
                data: (entries) {
                  if (entries.isEmpty) {
                    return const DesiEmptyState(
                      icon: Icons.leaderboard_outlined,
                      title: 'No Rankings Yet',
                      subtitle:
                          'Play matches and connect Firebase to compete on global leaderboards.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final e = entries[idx];
                      final isMe = e.uid == myUid;
                      final rankColor = switch (e.rank) {
                        1 => AppColors.goldAccent,
                        2 => const Color(0xFFCBD5E1),
                        3 => const Color(0xFFFB923C),
                        _ => AppColors.secondaryAccent,
                      };
                      return DesiGlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        borderColor: isMe
                            ? AppColors.saffronAccent
                            : (e.rank <= 3
                                  ? rankColor.withValues(alpha: 0.5)
                                  : AppColors.borderSubtle),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 34,
                              child: Text(
                                '#${e.rank}',
                                style: TextStyle(
                                  color: rankColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            PlayerAvatar(avatarId: e.avatarId, size: 40),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isMe ? '${e.username} (You)' : e.username,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  Text(
                                    '${e.wins} Wins • ${e.totalGames} Matches',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: rankColor.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(
                                  AppRadii.pill,
                                ),
                              ),
                              child: Text(
                                '${e.rating}',
                                style: TextStyle(
                                  color: rankColor,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
