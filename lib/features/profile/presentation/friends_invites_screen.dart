import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/desi_buttons.dart';
import '../../../core/widgets/desi_states.dart';
import '../../../shared/app_providers.dart';

class FriendsInvitesScreen extends ConsumerStatefulWidget {
  const FriendsInvitesScreen({super.key});

  @override
  ConsumerState<FriendsInvitesScreen> createState() =>
      _FriendsInvitesScreenState();
}

class _FriendsInvitesScreenState extends ConsumerState<FriendsInvitesScreen> {
  final _usernameCtrl = TextEditingController();
  final _roomCodeCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _roomCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    final target = _usernameCtrl.text.trim();
    if (target.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(friendsProvider.notifier)
          .sendInvite(
            target,
            roomCode: _roomCodeCtrl.text.trim().isEmpty
                ? null
                : _roomCodeCtrl.text.trim().toUpperCase(),
          );
      _usernameCtrl.clear();
      _roomCodeCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invite sent to $target!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invites = ref.watch(friendsProvider);
    final user = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Friends & Invites')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            DesiGlassCard(
              borderColor: AppColors.turquoiseAccent.withValues(alpha: 0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invite a Friend to DESI GUESS',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Friend\'s Username',
                      prefixIcon: Icon(Icons.person_search_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _roomCodeCtrl,
                    maxLength: 6,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Optional 6-Char Room Code',
                      counterText: '',
                      prefixIcon: Icon(Icons.meeting_room_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: DesiPrimaryButton(
                          label: 'Send Invite',
                          icon: Icons.send_rounded,
                          isLoading: _sending,
                          onPressed: _sendInvite,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DesiSecondaryButton(
                          label: 'Share Link',
                          icon: Icons.share_rounded,
                          onPressed: () {
                            Share.share(
                              'Challenge me on DESI GUESS! My username is ${user?.username ?? 'DesiPlayer'}.',
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
            Text('Sent Invites', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (invites.isEmpty)
              const DesiEmptyState(
                icon: Icons.group_outlined,
                title: 'No Invites Yet',
                subtitle:
                    'Send a friend invite above or share your room code directly on WhatsApp.',
              )
            else
              ...invites.map(
                (inv) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DesiGlassCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.mail_outline_rounded,
                          color: AppColors.secondaryAccent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                inv.toUsername,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                inv.roomCode != null
                                    ? 'Room Code: ${inv.roomCode} • ${inv.status}'
                                    : 'Status: ${inv.status}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
