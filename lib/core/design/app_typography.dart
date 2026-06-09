import 'package:flutter/material.dart';
import 'app_colors.dart';

@immutable
class AppTypography {
  const AppTypography._();

  static const _defaultColor = AppColors.textPrimary;

  static const largeTitle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    color: _defaultColor,
    letterSpacing: -0.5,
  );

  static const title1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: _defaultColor,
  );

  static const title2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: _defaultColor,
  );

  static const headline = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: _defaultColor,
  );

  static const body = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: _defaultColor,
  );

  static const callout = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: _defaultColor,
  );

  static const subhead = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: _defaultColor,
  );

  static const footnote = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: _defaultColor,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: _defaultColor,
  );

  static const subtitleMuted = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );

  static const fieldLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );

  static const fieldText = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const fieldHint = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: AppColors.textHint,
  );

  static const errorText = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.destructive,
  );
}
