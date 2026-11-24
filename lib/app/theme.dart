import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_colors.dart';

/// Premium Material 3 themes for DESI GUESS.
abstract final class AppTheme {
  /// Disabled only in headless `--no-test-assets` unit tests where
  /// `AssetManifest.bin` is not bundled. Always true in production runs.
  static bool useGoogleFonts = true;

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = _buildTextTheme(
      base.textTheme,
      AppColors.textPrimary,
      AppColors.textSecondary,
    );

    return base.copyWith(
      brightness: Brightness.dark,
      splashFactory: InkRipple.splashFactory,
      scaffoldBackgroundColor: AppColors.primaryBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryAccent,
        secondary: AppColors.secondaryAccent,
        tertiary: AppColors.saffronAccent,
        surface: AppColors.secondaryBackground,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSecondary: AppColors.primaryBackground,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.secondaryBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 16,
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(
            color: AppColors.primaryAccent,
            width: 1.6,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.elevatedSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.xl),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
      ),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = _buildTextTheme(
      base.textTheme,
      AppColors.lightTextPrimary,
      AppColors.lightTextSecondary,
    );

    return base.copyWith(
      brightness: Brightness.light,
      splashFactory: InkRipple.splashFactory,
      scaffoldBackgroundColor: AppColors.lightPrimaryBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryAccent,
        secondary: AppColors.secondaryAccent,
        tertiary: AppColors.saffronAccent,
        surface: AppColors.lightSecondaryBackground,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSurface: AppColors.lightTextPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.lightTextPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.lightTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSecondaryBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: const BorderSide(color: Color(0xFFDCE3F0)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSecondaryBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: Color(0xFFDCE3F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(
            color: AppColors.primaryAccent,
            width: 1.6,
          ),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(
    TextTheme base,
    Color primary,
    Color secondary,
  ) {
    final displayFont = useGoogleFonts ? GoogleFonts.outfit().fontFamily : null;
    final bodyFont = useGoogleFonts
        ? GoogleFonts.plusJakartaSans().fontFamily
        : null;
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontFamily: displayFont,
        color: primary,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontFamily: displayFont,
        color: primary,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontFamily: displayFont,
        color: primary,
        fontWeight: FontWeight.w800,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontFamily: displayFont,
        color: primary,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontFamily: displayFont,
        color: primary,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontFamily: displayFont,
        color: primary,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontFamily: displayFont,
        color: primary,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontFamily: bodyFont,
        color: primary,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontFamily: bodyFont,
        color: secondary,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.bodyLarge?.copyWith(fontFamily: bodyFont, color: primary),
      bodyMedium: base.bodyMedium?.copyWith(
        fontFamily: bodyFont,
        color: secondary,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontFamily: bodyFont,
        color: secondary,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontFamily: bodyFont,
        color: primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
