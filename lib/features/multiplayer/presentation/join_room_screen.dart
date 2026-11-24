import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/room_code_generator.dart';
import '../../../core/widgets/desi_buttons.dart';
import '../../../core/widgets/desi_states.dart';
import '../../../shared/app_providers.dart';

class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  late final TextEditingController _codeController;
  bool _joining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(
      text: widget.initialCode?.toUpperCase() ?? '',
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim().toUpperCase();
    if (!AppUtils.isValidRoomCode(code)) {
      setState(
        () => _error = 'Enter a valid 6-character alphanumeric room code.',
      );
      return;
    }
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final roomId = await ref
          .read(multiplayerRepositoryProvider)
          .joinRoom(code);
      if (!mounted) return;
      context.go('/online/lobby/$roomId');
    } on AppFailure catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Online Room')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DesiGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter 6-Character Room Code',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ask your friend for the 6-character invite code displayed in their Online Lobby.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _codeController,
                      maxLength: 6,
                      textCapitalization: TextCapitalization.characters,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            letterSpacing: 8,
                            fontWeight: FontWeight.w900,
                          ),
                      decoration: const InputDecoration(
                        hintText: 'A7K9P2',
                        counterText: '',
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: 22),
              DesiPrimaryButton(
                label: 'Join Room',
                icon: Icons.meeting_room_rounded,
                isLoading: _joining,
                onPressed: _join,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
