import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';

/// The design's centred empty state: a clay icon tile, a display-face title, a
/// muted body and an optional call to action.
class RepairEmptyState extends StatelessWidget {
  const RepairEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClayContainer(
              variant: ClayVariant.soft,
              color: lum.surface,
              borderRadius: AppRadius.clay,
              isDark: lum.isDark,
              width: 72,
              height: 72,
              child: Center(child: Icon(icon, size: 30, color: lum.g400)),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.title2.copyWith(
                fontSize: 19,
                color: lum.g700,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(height: 1.5, color: lum.g500),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// The design's error state — same shape as the empty state on a danger tile.
class RepairErrorState extends StatelessWidget {
  const RepairErrorState({
    super.key,
    required this.title,
    required this.body,
    this.onRetry,
  });

  final String title;
  final String body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClayContainer(
              variant: ClayVariant.soft,
              color: lum.dangerSoft,
              borderRadius: AppRadius.clay,
              isDark: lum.isDark,
              width: 72,
              height: 72,
              child: Center(
                child: Icon(LucideIcons.wifiOff, size: 30, color: lum.dangerText),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.title2.copyWith(
                fontSize: 19,
                color: lum.g700,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(height: 1.5, color: lum.g500),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              AppButton(
                label: 'Try again',
                variant: AppButtonVariant.tinted,
                icon: LucideIcons.refreshCw,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
