import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/widgets/desi_states.dart';
import '../../../shared/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('settings'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _SectionLabel('Audio & Haptics'),
            DesiGlassCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(l10n.t('sound_effects')),
                    subtitle: const Text(
                      'Card taps, heart alerts & victory chimes',
                    ),
                    value: settings.soundEnabled,
                    activeTrackColor: AppColors.primaryAccent,
                    onChanged: notifier.setSoundEnabled,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: Text(l10n.t('vibration')),
                    subtitle: const Text(
                      'Tactile haptics on turns and guesses',
                    ),
                    value: settings.vibrationEnabled,
                    activeTrackColor: AppColors.primaryAccent,
                    onChanged: notifier.setVibrationEnabled,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: Text(l10n.t('background_music')),
                    subtitle: const Text('Subtle ambient lobby loop'),
                    value: settings.musicEnabled,
                    activeTrackColor: AppColors.primaryAccent,
                    onChanged: notifier.setMusicEnabled,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SectionLabel('Appearance & Language'),
            DesiGlassCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(l10n.t('dark_theme')),
                    subtitle: const Text('Midnight navy & violet gaming look'),
                    value: settings.darkMode,
                    activeTrackColor: AppColors.primaryAccent,
                    onChanged: notifier.setDarkMode,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: Text(l10n.t('language')),
                    subtitle: Text(
                      settings.languageCode == 'hi' ? 'Hinglish' : 'English',
                    ),
                    trailing: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'en', label: Text('EN')),
                        ButtonSegment(value: 'hi', label: Text('Hinglish')),
                      ],
                      selected: {settings.languageCode},
                      onSelectionChanged: (s) =>
                          notifier.setLanguageCode(s.first),
                    ),
                  ),
                ],
              ),
            ),
            if (FeatureFlags.enableOnlineInvites) ...[
              const SizedBox(height: 20),
              _SectionLabel('Privacy'),
              DesiGlassCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Allow Friend Invites'),
                      subtitle: const Text(
                        'Let players invite you using username',
                      ),
                      value: settings.allowFriendInvites,
                      activeTrackColor: AppColors.primaryAccent,
                      onChanged: notifier.setAllowFriendInvites,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Anonymous Analytics & Crash Reports'),
                      subtitle: const Text(
                        'Helps improve DESI GUESS stability',
                      ),
                      value: settings.analyticsEnabled,
                      activeTrackColor: AppColors.primaryAccent,
                      onChanged: notifier.setAnalyticsEnabled,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            _SectionLabel(
              FeatureFlags.enableCloudAccounts
                  ? 'Account & Help'
                  : 'Profile & Help',
            ),
            DesiGlassCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.help_outline_rounded),
                    title: Text(l10n.t('help_and_rules')),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/help'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.logout_rounded,
                      color: AppColors.danger,
                    ),
                    title: Text(
                      FeatureFlags.enableCloudAccounts
                          ? 'Sign Out'
                          : 'Switch Local Profile',
                      style: const TextStyle(color: AppColors.danger),
                    ),
                    onTap: () async {
                      final cloud = FeatureFlags.enableCloudAccounts;
                      final confirmed = await showDesiConfirmDialog(
                        context,
                        title: cloud ? 'Sign Out?' : 'Switch Local Profile?',
                        message: cloud
                            ? 'You can sign back in or enter Guest Mode anytime.'
                            : 'Choose a new nickname and avatar for Pass-and-Play.',
                        confirmLabel: cloud ? 'Sign Out' : 'Switch Profile',
                        isDestructive: true,
                      );
                      if (!confirmed) return;
                      await ref.read(authProvider.notifier).signOut();
                      if (!context.mounted) return;
                      context.go(cloud ? '/login' : '/guest-login');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.secondaryAccent,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
