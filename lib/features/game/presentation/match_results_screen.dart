import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/room_code_generator.dart';
import '../../../core/widgets/desi_buttons.dart';
import '../../../core/widgets/desi_states.dart';
import '../../../core/widgets/hearts_indicator.dart';
import '../../../models/game_models.dart';
import '../../../shared/app_providers.dart';

/// Dramatic Victory & Defeat screen with confetti, revealed secrets, match stats, and rematch.
class MatchResultsScreen extends ConsumerStatefulWidget {
  const MatchResultsScreen({super.key});

  @override
  ConsumerState<MatchResultsScreen> createState() => _MatchResultsScreenState();
}

class _MatchResultsScreenState extends ConsumerState<MatchResultsScreen> {
  late final ConfettiController _confettiController;
  bool _rematchLoading = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = ref.watch(lastMatchResultProvider);

    if (result == null) {
      return Scaffold(
        body: DesiEmptyState(
          icon: Icons.emoji_events_outlined,
          title: 'No Match Result',
          subtitle: 'Finish a match to see full victory stats here.',
          actionLabel: 'Back to Home',
          onAction: () => context.go('/home'),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.35),
                radius: 1.1,
                colors: [Color(0xFF331F66), AppColors.primaryBackground],
              ),
            ),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.saffronGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.saffronAccent.withValues(
                              alpha: 0.45,
                            ),
                            blurRadius: 26,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        size: 52,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.t('victory_title'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.goldAccent,
                      letterSpacing: 3.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${result.winnerName} Wins!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.winReason,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.turquoiseAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: HeartsIndicator(
                      hearts: result.winnerHeartsRemaining,
                      label: 'Winner Hearts',
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Revealed Secret Cards (Local Mode)
                  if (result.player1SecretName != null ||
                      result.player2SecretName != null) ...[
                    DesiGlassCard(
                      borderColor: AppColors.saffronAccent.withValues(
                        alpha: 0.45,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Secret Cards Revealed',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 10),
                          if (result.player1SecretName != null)
                            _ResultRow(
                              label: 'Player 1 Secret',
                              value: result.player1SecretName!,
                              highlight: AppColors.secondaryAccent,
                            ),
                          if (result.player2SecretName != null) ...[
                            const SizedBox(height: 6),
                            _ResultRow(
                              label: 'Player 2 Secret',
                              value: result.player2SecretName!,
                              highlight: AppColors.saffronAccent,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Match Breakdown
                  DesiGlassCard(
                    child: Column(
                      children: [
                        _ResultRow(
                          label: 'Board Pack',
                          value:
                              '${result.packName} (${result.category.displayName})',
                        ),
                        const Divider(height: 20),
                        _ResultRow(
                          label: l10n.t('questions_asked'),
                          value: '${result.questionsAsked}',
                        ),
                        const Divider(height: 20),
                        _ResultRow(
                          label: l10n.t('wrong_guesses'),
                          value: '${result.incorrectGuesses}',
                        ),
                        const Divider(height: 20),
                        _ResultRow(
                          label: l10n.t('match_duration'),
                          value: AppUtils.formatDuration(
                            result.durationSeconds,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  DesiPrimaryButton(
                    label: l10n.t('rematch'),
                    icon: Icons.replay_rounded,
                    gradient: AppColors.saffronGradient,
                    isLoading: _rematchLoading,
                    onPressed: () async {
                      setState(() => _rematchLoading = true);
                      if (result.mode == GameMode.online &&
                          result.roomId != null) {
                        try {
                          await ref
                              .read(multiplayerRepositoryProvider)
                              .requestRematch(result.roomId!);
                          if (!context.mounted) return;
                          context.go('/online/lobby/${result.roomId}');
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(e.toString())));
                        } finally {
                          if (mounted) setState(() => _rematchLoading = false);
                        }
                      } else {
                        final packs = ref
                            .read(cardRepositoryProvider)
                            .packsForCategory(result.category);
                        await ref
                            .read(localMatchProvider.notifier)
                            .startRematch(sourcePacks: packs);
                        if (!context.mounted) return;
                        context.go(
                          result.category == GameCategory.custom
                              ? '/game/secret-select'
                              : '/game/preview',
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DesiSecondaryButton(
                    label: l10n.t('back_home'),
                    icon: Icons.home_rounded,
                    onPressed: () async {
                      await ref.read(localMatchProvider.notifier).clearMatch();
                      if (!context.mounted) return;
                      context.go('/home');
                    },
                  ),
                ],
              ),
            ),
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              AppColors.primaryAccent,
              AppColors.saffronAccent,
              AppColors.turquoiseAccent,
              AppColors.goldAccent,
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value, this.highlight});

  final String label;
  final String value;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: highlight ?? Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
