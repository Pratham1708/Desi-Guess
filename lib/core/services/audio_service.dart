import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

enum GameSfx {
  buttonTap('sounds/button_tap.wav'),
  cardSelect('sounds/card_select.wav'),
  cardEliminate('sounds/card_eliminate.wav'),
  heartLoss('sounds/heart_loss.wav'),
  turnChime('sounds/turn_chime.wav'),
  victory('sounds/victory.wav');

  const GameSfx(this.assetPath);
  final String assetPath;
}

/// Manages game sound effects and haptics with safe test-environment guards.
class AudioService {
  AudioService({bool enabled = true, bool hapticsEnabled = true})
    : _soundEnabled = enabled,
      _vibrationEnabled = hapticsEnabled;

  AudioPlayer? _sfxPlayer;
  bool _soundEnabled;
  bool _vibrationEnabled;

  void updatePreferences({
    required bool soundEnabled,
    required bool vibrationEnabled,
  }) {
    _soundEnabled = soundEnabled;
    _vibrationEnabled = vibrationEnabled;
  }

  Future<void> play(GameSfx sfx) async {
    if (_vibrationEnabled) {
      try {
        await _triggerHaptic(sfx).timeout(const Duration(milliseconds: 120));
      } catch (_) {}
    }
    if (!_soundEnabled) return;
    try {
      _sfxPlayer ??= AudioPlayer();
      await _sfxPlayer!.stop().timeout(
        const Duration(milliseconds: 200),
        onTimeout: () {},
      );
      await _sfxPlayer!
          .play(AssetSource(sfx.assetPath), volume: 0.75)
          .timeout(const Duration(milliseconds: 300), onTimeout: () {});
    } catch (_) {
      // Gracefully ignore audio errors on headless/test platforms.
    }
  }

  Future<void> _triggerHaptic(GameSfx sfx) async {
    try {
      switch (sfx) {
        case GameSfx.buttonTap:
          await HapticFeedback.selectionClick();
        case GameSfx.cardSelect:
          await HapticFeedback.mediumImpact();
        case GameSfx.cardEliminate:
          await HapticFeedback.lightImpact();
        case GameSfx.heartLoss:
          await HapticFeedback.heavyImpact();
        case GameSfx.turnChime:
          await HapticFeedback.selectionClick();
        case GameSfx.victory:
          await HapticFeedback.heavyImpact();
      }
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _sfxPlayer?.dispose();
    } catch (_) {}
  }
}
