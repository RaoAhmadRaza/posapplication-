import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../app_colors.dart';
import '../app_radius.dart';
import '../app_typography.dart';
import '../clay.dart';
import 'app_button.dart';

/// The design's centred empty state: a clay icon tile, a display-face title, a
/// muted body and an optional call to action.
///
/// Lifted verbatim out of the repair module when suppliers needed the same
/// shape; `repair_states.dart` aliases these names so its call sites are
/// unaffected.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
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
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.title,
    required this.body,
    this.onRetry,
    this.icon = LucideIcons.wifiOff,
    this.retryLabel = 'Try again',
  });

  final String title;
  final String body;
  final VoidCallback? onRetry;

  /// Defaults to the offline glyph the repair module shipped with.
  final IconData icon;
  final String retryLabel;

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
                child: Icon(icon, size: 30, color: lum.dangerText),
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
                label: retryLabel,
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
