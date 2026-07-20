import 'package:flutter/material.dart';

/// LUMINA POS palette — iOS-vivid, warm-tinted paper neutrals + one electric
/// accent (Lumen). Ported from the design system `tokens/colors.css`.
///
/// Two layers live here:
///   1. [AppColors] — light-only static consts, kept API-compatible with the
///      rest of the app (every feature reads these). Values remapped to Lumina.
///   2. [LumColors] — a theme-aware [ThemeExtension] carrying the full light +
///      dark palette. Reskinned widgets read it via `context.lum` so dark
///      ("Counter") mode works. Legacy pages keep using [AppColors] (light).
@immutable
class AppColors {
  const AppColors._();

  // ---- App chrome (light) ----
  static const background = Color(0xFFFFFFFF); // card/scaffold surface (legacy)
  static const paper = Color(0xFFF2F2F7); // warm app background
  static const surface = Color(0xFFFFFFFF); // cards, sheets, modals
  static const surface2 = Color(0xFFE8E8ED); // inputs, inset wells
  static const fieldFill = Color(0xFFE8E8ED);
  static const separator = Color(0xFFD9D9DF); // hairline
  static const hairline = Color(0xFFD9D9DF);
  static const hairline2 = Color(0xFFC7C7CC);

  // ---- Text (light) ----
  static const textPrimary = Color(0xFF10131C); // ink
  static const textMuted = Color(0xFF67635A); // g600
  static const textTertiary = Color(0xFF8C8879); // g500
  static const textHint = Color(0xFFB4B0A4); // g400

  // ---- Signature accent (Lumen) ----
  static const accent = Color(0xFF2C6BFF);
  static const accentPress = Color(0xFF1A52E6);
  static const accentSoft = Color(0xFFE5EDFF);
  static const beam = Color(0xFFFF9F45);
  static const beamSoft = Color(0xFFFFF1E2);

  // ---- Ink surfaces (hero / splash panels) ----
  static const ink = Color(0xFF10131C);
  static const ink2 = Color(0xFF1B2030);

  // ---- Semantic (light) ----
  static const destructive = Color(0xFFFF453A);
  static const destructiveSoft = Color(0xFFFFE7E4);
  static const destructiveText = Color(0xFFD32B26);
  static const success = Color(0xFF15B374);
  static const successSoft = Color(0xFFE3F6EC);
  static const successText = Color(0xFF0E8A57);
  static const warning = Color(0xFFFF9F0A);
  static const warningSoft = Color(0xFFFFF1DA);
  static const warningText = Color(0xFF9A5E00);
  static const transit = Color(0xFF8B5CF6);
  static const transitSoft = Color(0xFFEEE9FE);
  static const transitText = Color(0xFF6A34E0);

  // ---- Warm neutral scale ----
  static const g50 = Color(0xFFF7F7FA);
  static const g100 = Color(0xFFF1F1F5);
  static const g200 = Color(0xFFE7E5DD);
  static const g300 = Color(0xFFD6D3C9);
  static const g400 = Color(0xFFB4B0A4);
  static const g500 = Color(0xFF8C8879);
  static const g600 = Color(0xFF67635A);
  static const g700 = Color(0xFF4A4740);
  static const g800 = Color(0xFF2F2D29);
  static const g900 = Color(0xFF1B1A17);
}

/// Theme-aware palette. Read with `context.lum` inside reskinned widgets.
@immutable
class LumColors extends ThemeExtension<LumColors> {
  const LumColors({
    required this.paper,
    required this.surface,
    required this.surface2,
    required this.hairline,
    required this.hairline2,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.accent,
    required this.accentPress,
    required this.accentSoft,
    required this.beam,
    required this.beamSoft,
    required this.ink,
    required this.success,
    required this.successSoft,
    required this.successText,
    required this.warning,
    required this.warningSoft,
    required this.warningText,
    required this.danger,
    required this.dangerSoft,
    required this.dangerText,
    required this.g100,
    required this.g200,
    required this.g300,
    required this.g400,
    required this.g500,
    required this.g600,
    required this.g700,
    required this.isDark,
  });

  final Color paper;
  final Color surface;
  final Color surface2;
  final Color hairline;
  final Color hairline2;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;
  final Color accent;
  final Color accentPress;
  final Color accentSoft;
  final Color beam;
  final Color beamSoft;
  final Color ink;
  final Color success;
  final Color successSoft;
  final Color successText;
  final Color warning;
  final Color warningSoft;
  final Color warningText;
  final Color danger;
  final Color dangerSoft;
  final Color dangerText;
  final Color g100;
  final Color g200;
  final Color g300;
  final Color g400;
  final Color g500;
  final Color g600;
  final Color g700;
  final bool isDark;

  static const light = LumColors(
    paper: Color(0xFFF2F2F7),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFE8E8ED),
    hairline: Color(0xFFD9D9DF),
    hairline2: Color(0xFFC7C7CC),
    textPrimary: Color(0xFF10131C),
    textSecondary: Color(0xFF67635A),
    textTertiary: Color(0xFF8C8879),
    textDisabled: Color(0xFFB4B0A4),
    accent: Color(0xFF2C6BFF),
    accentPress: Color(0xFF1A52E6),
    accentSoft: Color(0xFFE5EDFF),
    beam: Color(0xFFFF9F45),
    beamSoft: Color(0xFFFFF1E2),
    ink: Color(0xFF10131C),
    success: Color(0xFF15B374),
    successSoft: Color(0xFFE3F6EC),
    successText: Color(0xFF0E8A57),
    warning: Color(0xFFFF9F0A),
    warningSoft: Color(0xFFFFF1DA),
    warningText: Color(0xFF9A5E00),
    danger: Color(0xFFFF453A),
    dangerSoft: Color(0xFFFFE7E4),
    dangerText: Color(0xFFD32B26),
    g100: Color(0xFFF1F1F5),
    g200: Color(0xFFE7E5DD),
    g300: Color(0xFFD6D3C9),
    g400: Color(0xFFB4B0A4),
    g500: Color(0xFF8C8879),
    g600: Color(0xFF67635A),
    g700: Color(0xFF4A4740),
    isDark: false,
  );

  // Dark "Counter mode" — deep ink surfaces, brightened Lumen, lifted semantics.
  static const dark = LumColors(
    paper: Color(0xFF0B0E16),
    surface: Color(0xFF161B28),
    surface2: Color(0xFF1F2535),
    hairline: Color(0xFF2A3142),
    hairline2: Color(0xFF38415A),
    textPrimary: Color(0xFFECEEF4),
    textSecondary: Color(0xFF9AA0B2),
    textTertiary: Color(0xFF7B8199),
    textDisabled: Color(0xFF5A6072),
    accent: Color(0xFF5E86FF),
    accentPress: Color(0xFF4366E6),
    accentSoft: Color(0x2E5E86FF), // rgba(94,134,255,.18)
    beam: Color(0xFFFFB26B),
    beamSoft: Color(0x33FF9F45),
    ink: Color(0xFF0B0E16),
    success: Color(0xFF28C786),
    successSoft: Color(0x2628C786),
    successText: Color(0xFF5BE0AC),
    warning: Color(0xFFFFB23D),
    warningSoft: Color(0x26FFB23D),
    warningText: Color(0xFFFFC978),
    danger: Color(0xFFFF6961),
    dangerSoft: Color(0x26FF6961),
    dangerText: Color(0xFFFF9A94),
    g100: Color(0xFF1F2535),
    g200: Color(0xFF2A3142),
    g300: Color(0xFF38415A),
    g400: Color(0xFF7B8199),
    g500: Color(0xFF9AA0B2),
    g600: Color(0xFFB6BCCC),
    g700: Color(0xFFD2D6E0),
    isDark: true,
  );

  @override
  LumColors copyWith() => this;

  @override
  LumColors lerp(ThemeExtension<LumColors>? other, double t) {
    if (other is! LumColors) return this;
    return t < 0.5 ? this : other;
  }
}

/// Convenience access to the active [LumColors] from a build context.
extension LumColorsContext on BuildContext {
  LumColors get lum => Theme.of(this).extension<LumColors>() ?? LumColors.light;
}
