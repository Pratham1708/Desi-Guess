import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/desi_buttons.dart';
import '../../../core/widgets/desi_states.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../models/game_models.dart';
import '../../../shared/app_providers.dart';

class OnlineLobbyScreen extends ConsumerStatefulWidget {
  const OnlineLobbyScreen({super.key, required this.roomId});
  final String roomId;

  @override
  ConsumerState<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends ConsumerState<OnlineLobbyScreen> {
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    final uid = ref.read(authProvider)?.uid;
    if (uid != null) {
      ref
          .read(multiplayerRepositoryProvider)
          .updatePresence(roomId: widget.roomId, uid: uid, connected: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(authProvider)?.uid ?? '';
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));
    final playersAsync = ref.watch(roomPlayersStreamProvider(widget.roomId));

    return roomAsync.when(
      loading: () => const Scaffold(
        body: DesiLoadingView(message: 'Connecting to lobby...'),
      ),
      error: (e, _) => Scaffold(body: DesiErrorState(message: e.toString())),
      data: (room) {
        if (room == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Online Lobby')),
            body: DesiEmptyState(
              icon: Icons.meeting_room_outlined,
              title: 'Room Closed or Expired',
              subtitle: 'Create a fresh room to play with your friend.',
              actionLabel: 'Back to Home',
              onAction: () => context.go('/home'),
            ),
          );
        }

        if (room.status == MatchStatus.selectingSecrets) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go('/game/secret-select?roomId=${widget.roomId}');
            }
          });
        } else if (room.status == MatchStatus.active) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go('/game/board?roomId=${widget.roomId}');
            }
          });
        }

        final players = playersAsync.valueOrNull ?? const [];
        final isHost = room.hostUid == myUid;
        final pack = ref
            .watch(cardRepositoryProvider)
            .findPackById(room.boardPackId);
        final bothJoined = players.length >= 2 || room.hasGuest;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Online Lobby'),
            actions: [
              IconButton(
                tooltip: 'Leave Room',
                onPressed: () async {
                  await ref
                      .read(multiplayerRepositoryProvider)
                      .leaveRoom(widget.roomId);
                  if (!context.mounted) return;
                  context.go('/home');
                },
                icon: const Icon(Icons.exit_to_app_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                // Room Code Card
                DesiGlassCard(
                  borderColor: AppColors.saffronAccent.withValues(alpha: 0.6),
                  child: Column(
                    children: [
                      const Text(
                        'ROOM INVITE CODE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                          color: AppColors.saffronAccent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        room.roomCode,
                        style: Theme.of(
                          context,
                        ).textTheme.displaySmall?.copyWith(letterSpacing: 8),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: DesiSecondaryButton(
                              label: 'Copy Code',
                              icon: Icons.copy_rounded,
                              height: 44,
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: room.roomCode),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Room code copied!'),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DesiPrimaryButton(
                              label: 'Share Invite',
                              icon: Icons.share_rounded,
                              height: 44,
                              onPressed: () {
                                Share.share(
                                  'Join my DESI GUESS match! Room Code: ${room.roomCode}',
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Selected Pack Summary
                DesiGlassCard(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.style_rounded,
                        color: AppColors.secondaryAccent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pack?.name ??
                                  '${room.category.displayName} • Random 10 Board',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${room.category.displayName} • '
                              '${room.turnTimerSeconds != null ? '${room.turnTimerSeconds}s turn timer' : 'No turn timer'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Players Roster
                Text(
                  'Players (${players.length}/2)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                ...players.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DesiGlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          PlayerAvatar(
                            avatarId: p.avatarId,
                            size: 42,
                            isOnline: p.isConnected,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.displayName,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text(
                                  p.playerId == room.hostUid
                                      ? 'Room Host'
                                      : 'Challenger',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Chip(
                            label: Text(p.isReady ? 'Ready' : 'Joined'),
                            backgroundColor: p.isReady
                                ? AppColors.success.withValues(alpha: 0.2)
                                : AppColors.elevatedSurface,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (!bothJoined)
                  DesiGlassCard(
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppColors.turquoiseAccent,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Waiting for opponent to enter your room code...',
                              ),
                            ),
                          ],
                        ),
                      )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .fade(begin: 0.7, end: 1.0, duration: 900.ms),

                const SizedBox(height: 28),

                if (isHost)
                  DesiPrimaryButton(
                    label: bothJoined
                        ? 'Start Match'
                        : 'Waiting for Player 2...',
                    icon: Icons.play_arrow_rounded,
                    gradient: AppColors.saffronGradient,
                    isLoading: _starting,
                    onPressed: bothJoined
                        ? () async {
                            setState(() => _starting = true);
                            try {
                              await ref
                                  .read(multiplayerRepositoryProvider)
                                  .startMatch(widget.roomId);
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            } finally {
                              if (mounted) setState(() => _starting = false);
                            }
                          }
                        : null,
                  )
                else
                  DesiPrimaryButton(
                    label: 'Mark Ready',
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: () => ref
                        .read(multiplayerRepositoryProvider)
                        .setReady(
                          roomId: widget.roomId,
                          uid: myUid,
                          ready: true,
                        ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
