import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/desi_logo.dart';
import '../../../shared/app_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), _navigateNext);
  }

  void _navigateNext() {
    if (!mounted) return;
    final storage = ref.read(storageServiceProvider);
    final profile = ref.read(authProvider);
    if (!storage.isOnboardingDone()) {
      context.go('/onboarding');
    } else if (profile == null) {
      context.go(FeatureFlags.enableCloudAccounts ? '/login' : '/guest-login');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.1,
            colors: [Color(0xFF281952), AppColors.primaryBackground],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DesiLogo(size: 92, showWordmark: false)
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.easeOutBack)
                  .fadeIn(),
              const SizedBox(height: 22),
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.2,
                  ),
                  children: const [
                    TextSpan(text: 'DESI '),
                    TextSpan(
                      text: 'GUESS',
                      style: TextStyle(color: AppColors.saffronAccent),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.2),
              const SizedBox(height: 8),
              Text(
                'WHO • WHAT • WHERE',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.turquoiseAccent,
                  letterSpacing: 3.2,
                ),
              ).animate().fadeIn(delay: 450.ms),
              const SizedBox(height: 36),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: AppColors.primaryAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
