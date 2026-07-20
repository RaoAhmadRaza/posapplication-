import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_radius.dart';
import '../app_spacing.dart';
import '../app_typography.dart';

enum BannerType { error, success, info, warning }

class AppInlineBanner extends StatelessWidget {
  const AppInlineBanner({
    super.key,
    required this.message,
    this.type = BannerType.error,
  });

  final String message;
  final BannerType type;

  @override
  Widget build(BuildContext context) {
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
          Icons.cloud_off_outlined,
        ),
      BannerType.info => (lum.accentSoft, lum.accent, Icons.info_outline),
    };

    final banner = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 16),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.footnote.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );

    // Fade + slide-in on appearance so errors/success don't pop abruptly.
    // liveRegion so screen readers announce the message when it appears.
    return Semantics(
      liveRegion: true,
      container: true,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(message),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        tween: Tween(begin: 0, end: 1),
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * -6),
            child: child,
          ),
        ),
        child: banner,
      ),
    );
  }
}
