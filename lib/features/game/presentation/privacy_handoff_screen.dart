import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/widgets/desi_buttons.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../models/game_models.dart';
import '../../../shared/app_providers.dart';

/// Privacy cover screen between turns in Local Pass-and-Play mode
/// so players never accidentally glimpse each other's secret card or board.
class PrivacyHandoffScreen extends ConsumerWidget {
  const PrivacyHandoffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final match = ref.watch(localMatchProvider);

    if (match == null) {
      return Scaffold(
        body: Center(
          child: DesiPrimaryButton(
            label: 'Back to Home',
            fullWidth: false,
            onPressed: () => context.go('/home'),
          ),
        ),
      );
    }

    final targetPlayer = match.handoffTargetPlayerId != null
        ? match.playerById(match.handoffTargetPlayerId!)
        : match.activePlayer;
    final isSecretPhase = match.status == MatchStatus.selectingSecrets;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [Color(0xFF23184A), AppColors.primaryBackground],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryAccent.withValues(alpha: 0.16),
                      border: Border.all(
                        color: AppColors.secondaryAccent.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Icon(
                      Icons.visibility_off_rounded,
                      size: 40,
                      color: AppColors.secondaryAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.t('handoff_title').toUpperCase(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.saffronAccent,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: PlayerAvatar(
                    avatarId: targetPlayer.avatarId,
                    size: 76,
                    isActiveTurn: true,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  targetPlayer.displayName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 10),
                Text(
                  isSecretPhase
                      ? 'It is your turn to secretly pick your hidden card. ${l10n.t('handoff_subtitle')}'
                      : 'It is Turn ${match.turnNumber}. ${l10n.t('handoff_subtitle')}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                DesiPrimaryButton(
                  label: '${l10n.t('im_ready')} (${targetPlayer.displayName})',
                  icon: Icons.lock_open_rounded,
                  gradient: AppColors.saffronGradient,
                  onPressed: () async {
                    await ref
                        .read(localMatchProvider.notifier)
                        .acknowledgeHandoff();
                    if (!context.mounted) return;
                    if (isSecretPhase) {
                      context.go('/game/secret-select');
                    } else {
                      context.go('/game/board');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
