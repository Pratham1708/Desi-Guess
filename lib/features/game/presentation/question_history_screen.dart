import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/room_code_generator.dart';
import '../../../core/widgets/desi_states.dart';
import '../../../shared/app_providers.dart';

class QuestionHistoryScreen extends ConsumerWidget {
  const QuestionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final match = ref.watch(localMatchProvider);
    final entries = match?.questionHistory ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('question_history'))),
      body: SafeArea(
        child: entries.isEmpty
            ? const DesiEmptyState(
                icon: Icons.question_answer_outlined,
                title: 'No Questions Logged Yet',
                subtitle:
                    'Final guesses and optional question notes from your match will appear here.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final e = entries[entries.length - 1 - idx];
                  final accent = e.isFinalGuess
                      ? (e.wasCorrectGuess == true
                            ? AppColors.success
                            : AppColors.danger)
                      : AppColors.primaryAccent;
                  return DesiGlassCard(
                    borderColor: accent.withValues(alpha: 0.45),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              e.askerName,
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              AppUtils.formatTimestamp(e.timestamp),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          e.question,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (e.answer != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(
                                AppRadii.pill,
                              ),
                            ),
                            child: Text(
                              '${e.answeredBy ?? 'Answer'}: ${e.answer}',
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
