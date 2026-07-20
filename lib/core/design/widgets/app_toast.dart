import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_haptics.dart';
import '../app_radius.dart';
import '../app_typography.dart';
import 'app_inline_banner.dart';
import 'app_success_check.dart';

/// Floating toast built on ScaffoldMessenger, styled with the [BannerType]
/// palette. Use for transient success/error acknowledgements (e.g. "Password
/// updated", "Secret copied") instead of silently popping a screen.
void showAppToast(
  BuildContext context,
  String message, {
  BannerType type = BannerType.info,
}) {
  final lum = context.lum;
  final (Color bg, Color fg, IconData icon) = switch (type) {
    BannerType.error => (lum.dangerSoft, lum.dangerText, Icons.error_outline),
    BannerType.success => (
        lum.successSoft,
        lum.successText,
        Icons.check_circle_outline,
      ),
    BannerType.warning => (
        lum.warningSoft,
        lum.warningText,
        Icons.warning_amber_rounded,
      ),
    BannerType.info => (lum.accentSoft, lum.accent, Icons.info_outline),
  };

  if (type == BannerType.success) {
    AppHaptics.success();
  } else if (type == BannerType.error) {
    AppHaptics.error();
  }

  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bg,
        elevation: 0,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (type == BannerType.success)
              AppSuccessCheck(color: fg, size: 18)
            else
              Icon(icon, color: fg, size: 18),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                message,
                style: AppTypography.footnote.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
}
