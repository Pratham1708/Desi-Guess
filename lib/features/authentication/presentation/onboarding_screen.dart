import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/desi_buttons.dart';
import '../../../shared/app_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  List<({IconData icon, Color color, String badge, String title, String body})>
  get _slides => [
    (
      icon: Icons.style_rounded,
      color: AppColors.primaryAccent,
      badge: '450+ DESI CARDS',
      title: 'Guess Across Iconic Indian Packs',
      body:
          'Bollywood legends, Indian cricketers, street food, brands, monuments & more across WHO, WHAT and WHERE.',
    ),
    (
      icon: Icons.favorite_rounded,
      color: AppColors.danger,
      badge: 'FIVE-HEART DEDUCTION',
      title: 'Ask Unlimited Questions. Guess Smart.',
      body:
          'Ask natural Yes/No questions and eliminate cards freely. Every wrong final guess costs one of your 5 hearts!',
    ),
    FeatureFlags.enableOnlineMultiplayer
        ? (
            icon: Icons.groups_rounded,
            color: AppColors.turquoiseAccent,
            badge: 'ONLINE & PASS-AND-PLAY',
            title: 'Play Together or Anywhere',
            body:
                'Challenge a friend face-to-face offline with privacy handoff, or create a 6-letter online room with live chat.',
          )
        : (
            icon: Icons.groups_rounded,
            color: AppColors.turquoiseAccent,
            badge: 'PASS-AND-PLAY OFFLINE',
            title: 'Play Face-to-Face on One Phone',
            body:
                'Challenge a friend anywhere with randomized 10-card boards and Privacy Handoff — no internet or account required.',
          ),
  ];

  Future<void> _finish() async {
    await ref.read(storageServiceProvider).setOnboardingDone(true);
    if (!mounted) return;
    context.go(FeatureFlags.enableCloudAccounts ? '/login' : '/guest-login');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: _finish, child: const Text('Skip')),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, index) {
                    final s = _slides[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 136,
                          height: 136,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                s.color.withValues(alpha: 0.35),
                                s.color.withValues(alpha: 0.06),
                              ],
                            ),
                            border: Border.all(
                              color: s.color.withValues(alpha: 0.55),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(s.icon, size: 62, color: s.color),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: s.color.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: Text(
                            s.badge,
                            style: TextStyle(
                              color: s.color,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          s.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s.body,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: active ? 28 : 8,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.primaryAccent
                          : AppColors.borderSubtle,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),
              DesiPrimaryButton(
                label: isLast ? 'Get Started' : 'Next',
                icon: isLast
                    ? Icons.rocket_launch_rounded
                    : Icons.arrow_forward_rounded,
                onPressed: () {
                  if (isLast) {
                    _finish();
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
