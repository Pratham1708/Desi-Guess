import 'package:flutter/material.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/desi_states.dart';

class HelpRulesScreen extends StatelessWidget {
  const HelpRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final showOnline = FeatureFlags.enableOnlineMultiplayer;
    final rules = [
      (
        icon: Icons.style_rounded,
        color: AppColors.primaryAccent,
        title: '1. Fresh 10-Card Boards & Secret Cards',
        body:
            'Pick WHO, WHAT, or WHERE to deal a freshly randomized 10-card Indian board (or play a Custom Board). Each player gets a distinct secret card for the opponent to deduce.',
      ),
      (
        icon: Icons.question_answer_rounded,
        color: AppColors.turquoiseAccent,
        title: '2. Ask Unlimited Yes/No Questions',
        body: showOnline
            ? 'Ask natural questions verbally in Local Mode or via live in-app chat in Online Mode. Your opponent answers honestly with Yes or No. Normal questions NEVER cost hearts!'
            : 'Ask natural Yes/No questions out loud while playing face-to-face on one phone (you can also log Q&A in-app). Normal questions NEVER cost hearts!',
      ),
      (
        icon: Icons.touch_app_rounded,
        color: AppColors.saffronAccent,
        title: '3. Eliminate & Restore Cards',
        body:
            'Tap cards on your board to eliminate them as you narrow down suspects. Accidentally eliminated someone? Tap again anytime to restore them.',
      ),
      (
        icon: Icons.favorite_rounded,
        color: AppColors.danger,
        title: '4. The Five-Heart System',
        body:
            'Each player starts with 5 hearts and gets 1 Final Guess attempt per turn. A correct Final Guess wins immediately! An incorrect Final Guess deducts 1 heart. At 0 hearts, you lose.',
      ),
      (
        icon: Icons.security_rounded,
        color: AppColors.success,
        title: '5. Secret Privacy Protection',
        body: showOnline
            ? 'In Local Mode, a Privacy Handoff screen covers the board between turns. In Online Mode, your secret card is locked in a private Firestore document validated strictly by Cloud Functions.'
            : 'Between every turn, a Privacy Handoff screen hides the board so you can safely pass the phone without revealing your secret card or eliminations.',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('How to Play DESI GUESS')),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: rules.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, idx) {
            final r = rules[idx];
            return DesiGlassCard(
              borderColor: r.color.withValues(alpha: 0.4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: r.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(r.icon, color: r.color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          r.body,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
