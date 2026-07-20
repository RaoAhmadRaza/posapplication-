import 'package:flutter/material.dart';
import 'app_colors.dart';

/// LUMINA type — three families on an 8-pt rhythm (`tokens/typography.css`).
///   Clash Display → display / headings / hero numbers
///   Satoshi       → all interface text
///   JetBrains Mono → money, SKU, IMEI, ledgers (tabular figures)
///
/// Style names are kept API-compatible with existing pages; sizes + families
/// remapped to the design system. Default colours are the light-theme ink;
/// reskinned widgets override colour from `context.lum` for dark mode.
@immutable
class AppTypography {
  const AppTypography._();

  static const display = 'ClashDisplay';
  static const ui = 'Satoshi';
  static const mono = 'JetBrainsMono';

  static const _ink = AppColors.textPrimary;

  // ---- Display / headings (Clash Display) ----
  static const hero = TextStyle(
    fontFamily: display,
    fontSize: 40,
    height: 48 / 40,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.2,
    color: _ink,
  );

  static const largeTitle = TextStyle(
    fontFamily: display,
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.64,
    color: _ink,
  );

  static const title1 = TextStyle(
    fontFamily: display,
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: _ink,
  );

  static const title2 = TextStyle(
    fontFamily: display,
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.24,
    color: _ink,
  );

  static const title3 = TextStyle(
    fontFamily: display,
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w600,
    color: _ink,
  );

  // ---- Interface text (Satoshi) ----
  static const headline = TextStyle(
    fontFamily: ui,
    fontSize: 18,
    height: 26 / 18,
    fontWeight: FontWeight.w600,
    color: _ink,
  );

  static const body = TextStyle(
    fontFamily: ui,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w400,
    color: _ink,
  );

  static const bodyLarge = TextStyle(
    fontFamily: ui,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    color: _ink,
  );

  static const callout = TextStyle(
    fontFamily: ui,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    color: _ink,
  );

  static const subhead = TextStyle(
    fontFamily: ui,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w400,
    color: _ink,
  );

  static const label = TextStyle(
    fontFamily: ui,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
    color: _ink,
  );

  static const footnote = TextStyle(
    fontFamily: ui,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
    color: _ink,
  );

  static const caption = TextStyle(
    fontFamily: ui,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    color: _ink,
  );

  static const subtitleMuted = TextStyle(
    fontFamily: ui,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );

  // ---- Field styles ----
  static const fieldLabel = TextStyle(
    fontFamily: ui,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.g700,
  );

  static const fieldText = TextStyle(
    fontFamily: ui,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const fieldHint = TextStyle(
    fontFamily: ui,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textHint,
  );

  static const errorText = TextStyle(
    fontFamily: ui,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.destructiveText,
  );

  // ---- Money / numbers (JetBrains Mono, tabular) ----
  static const monoValue = TextStyle(
    fontFamily: mono,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
    color: _ink,
  );

  static const monoLarge = TextStyle(
    fontFamily: mono,
    fontSize: 32,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.64,
    fontFeatures: [FontFeature.tabularFigures()],
    color: _ink,
  );
}
