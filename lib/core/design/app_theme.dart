import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

/// LUMINA themes — light + dark ("Counter mode"). Both carry a [LumColors]
/// extension so reskinned widgets read palette via `context.lum`. Default font
/// is Satoshi; headings use Clash Display per style, numbers JetBrains Mono.
@immutable
class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(LumColors.light);
  static ThemeData get dark => _build(LumColors.dark);

  static ThemeData _build(LumColors lum) {
    final base = lum.isDark ? Brightness.dark : Brightness.light;
    return ThemeData(
      brightness: base,
      scaffoldBackgroundColor: lum.paper,
      primaryColor: lum.accent,
      fontFamily: AppTypography.ui,
      colorScheme: ColorScheme.fromSeed(
        seedColor: lum.accent,
        brightness: base,
        surface: lum.surface,
      ),
      extensions: [lum],
      textTheme: TextTheme(
        bodyLarge: AppTypography.body.copyWith(color: lum.textPrimary),
        bodyMedium: AppTypography.body.copyWith(color: lum.textPrimary),
        titleLarge: AppTypography.title2.copyWith(color: lum.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lum.surface2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: lum.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: lum.danger, width: 1.5),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
