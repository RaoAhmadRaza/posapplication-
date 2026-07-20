import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_radius.dart';
import '../app_typography.dart';
import '../clay.dart';
import 'app_button.dart';

/// Clay-styled confirmation dialog. Returns true if confirmed, false/null on
/// cancel or dismiss. Use before destructive actions (revoke device, sign out
/// a session, log out).
Future<bool> showAppConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) {
      final lum = ctx.lum;
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: ClayContainer(
          variant: ClayVariant.raised,
          color: lum.surface,
          borderRadius: AppRadius.xl,
          isDark: lum.isDark,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: AppTypography.title3.copyWith(color: lum.textPrimary),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: AppTypography.subhead.copyWith(color: lum.textSecondary),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: confirmLabel,
                variant: destructive
                    ? AppButtonVariant.destructive
                    : AppButtonVariant.filled,
                fullWidth: true,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
              const SizedBox(height: 8),
              AppButton(
                label: cancelLabel,
                variant: AppButtonVariant.plain,
                fullWidth: true,
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}
