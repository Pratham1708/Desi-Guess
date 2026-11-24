import 'package:flutter/material.dart';

/// DESI GUESS Design System Color Tokens.
abstract final class AppColors {
  // Core Dark Theme Surfaces
  static const Color primaryBackground = Color(0xFF0B1020);
  static const Color secondaryBackground = Color(0xFF141B2D);
  static const Color cardBackground = Color(0xFF1C2540);
  static const Color elevatedSurface = Color(0xFF232E4D);

  // Core Light Theme Surfaces
  static const Color lightPrimaryBackground = Color(0xFFF5F7FC);
  static const Color lightSecondaryBackground = Color(0xFFFFFFFF);
  static const Color lightCardBackground = Color(0xFFEEF2FA);
  static const Color lightTextPrimary = Color(0xFF10172A);
  static const Color lightTextSecondary = Color(0xFF53607A);

  // Brand & Semantic Accents
  static const Color primaryAccent = Color(0xFF8B5CF6);
  static const Color secondaryAccent = Color(0xFFA78BFA);
  static const Color saffronAccent = Color(0xFFFF9933);
  static const Color turquoiseAccent = Color(0xFF2DD4BF);
  static const Color goldAccent = Color(0xFFFBBF24);

  // Semantic Status
  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // Typography
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAAB3C5);
  static const Color textMuted = Color(0xFF6B7794);

  // Borders & Glass
  static const Color borderSubtle = Color(0xFF2B3759);
  static const Color glassFill = Color(0x26FFFFFF);
  static const Color glassBorder = Color(0x33A78BFA);

  // Gradients
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A1B54), Color(0xFF181F3A), Color(0xFF0E1730)],
  );

  static const LinearGradient primaryButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
  );

  static const LinearGradient saffronGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF9933), Color(0xFFF97316)],
  );

  static const LinearGradient turquoiseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2DD4BF), Color(0xFF0D9488)],
  );

  static const LinearGradient cardSurfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF232E4D), Color(0xFF161E34)],
  );
}

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class AppRadii {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
  static const double pill = 999;
}
