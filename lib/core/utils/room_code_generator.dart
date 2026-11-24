import 'dart:math';

import '../constants/app_constants.dart';

/// Utilities for room codes, formatting, and input validation.
abstract final class AppUtils {
  static const String _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final Random _random = Random.secure();

  static String generateRoomCode({int length = AppConstants.roomCodeLength}) {
    return List.generate(
      length,
      (_) => _codeChars[_random.nextInt(_codeChars.length)],
    ).join();
  }

  static bool isValidRoomCode(String code) {
    final clean = code.trim().toUpperCase();
    return RegExp(r'^[A-Z0-9]{6}$').hasMatch(clean);
  }

  static String sanitizeUsername(String input) {
    final trimmed = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return 'Desi Player';
    return trimmed.length > 24 ? trimmed.substring(0, 24) : trimmed;
  }

  static String formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes == 0) return '${seconds}s';
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  static String formatTimestamp(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
