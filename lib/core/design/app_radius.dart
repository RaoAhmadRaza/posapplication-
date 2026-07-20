import 'package:flutter/material.dart';

/// Continuous-corner (iOS) radii — design system `tokens/spacing.css`.
@immutable
class AppRadius {
  const AppRadius._();

  static const sm = 12.0; // chips, small controls
  static const md = 16.0; // fields, list items
  static const lg = 22.0; // cards, sheets
  static const xl = 28.0; // hero tiles, modals
  static const clay = 26.0; // puffy clay tiles / icon buttons
  static const pill = 999.0;

  // Legacy aliases (kept so existing pages compile).
  static const field = md; // 16
  static const button = sm; // 12
  static const card = lg; // 22
  static const chip = sm; // 12
}
