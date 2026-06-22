import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Modern minimalist theme — Material 3 with custom seed colors,
/// warm neutral surfaces, and Inter typography for a refined feel.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: Brightness.light,
    ).copyWith(
      surface: AppColors.lightSurface,
      surfaceContainerHighest: AppColors.lightSurfaceVariant,
      onSurface: AppColors.lightOnSurface,
      onSurfaceVariant: AppColors.lightOnSurfaceVariant,
      outline: AppColors.lightOutline,
    );

    return _build(
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.lightBackground,
      brightness: Brightness.light,
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: Brightness.dark,
    ).copyWith(
      surface: AppColors.darkSurface,
      surfaceContainerHighest: AppColors.darkSurfaceVariant,
      onSurface: AppColors.darkOnSurface,
      onSurfaceVariant: AppColors.darkOnSurfaceVariant,
      outline: AppColors.darkOutline,
    );

    return _build(
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.darkBackground,
      brightness: Brightness.dark,
    );
  }

  static ThemeData _build({
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Brightness brightness,
  }) {
    final textTheme = GoogleFonts.interTextTheme(
      brightness == Brightness.light
          ? ThemeData.light().textTheme
          : ThemeData.dark().textTheme,
    ).apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme,
      fontFamily: GoogleFonts.inter().fontFamily,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outline, width: 0.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.primary.withValues(alpha: 0.15),
        labelStyle: textTheme.labelMedium,
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline,
        thickness: 0.5,
        space: 0.5,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.15),
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}