import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/desi_buttons.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../shared/app_providers.dart';

class GuestLoginScreen extends ConsumerStatefulWidget {
  const GuestLoginScreen({super.key});

  @override
  ConsumerState<GuestLoginScreen> createState() => _GuestLoginScreenState();
}

class _GuestLoginScreenState extends ConsumerState<GuestLoginScreen> {
  final _nameController = TextEditingController(text: 'Desi Challenger');
  String _selectedAvatar = 'avatar_1';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _enterAsGuest() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .signInAsGuest(
            username: _nameController.text,
            avatarId: _selectedAvatar,
          );
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          FeatureFlags.enableCloudAccounts
              ? 'Quick Guest Play'
              : 'Player Setup',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: PlayerAvatar(
                  avatarId: _selectedAvatar,
                  size: 88,
                  isActiveTurn: true,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Choose Your Avatar',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 14,
                runSpacing: 14,
                children: PlayerAvatar.presets.map((p) {
                  final selected = p.id == _selectedAvatar;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedAvatar = p.id),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PlayerAvatar(
                          avatarId: p.id,
                          size: 52,
                          isActiveTurn: selected,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: selected
                                ? AppColors.saffronAccent
                                : AppColors.textSecondary,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _nameController,
                maxLength: 24,
                decoration: const InputDecoration(
                  labelText: 'Player Nickname',
                  hintText: 'e.g., KingKohliFan',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: 22),
              DesiPrimaryButton(
                label: 'Enter DESI GUESS',
                icon: Icons.play_arrow_rounded,
                gradient: AppColors.saffronGradient,
                isLoading: _loading,
                onPressed: _enterAsGuest,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
