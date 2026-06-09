import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_radius.dart';
import '../app_spacing.dart';
import '../app_typography.dart';

enum BannerType { error, success, info }

class AppInlineBanner extends StatelessWidget {
  const AppInlineBanner({
    super.key,
    required this.message,
    this.type = BannerType.error,
  });

  final String message;
  final BannerType type;

  Color get _fgColor {
    switch (type) {
      case BannerType.error:
        return AppColors.destructive;
      case BannerType.success:
        return AppColors.success;
      case BannerType.info:
        return AppColors.accent;
    }
  }

  IconData get _icon {
    switch (type) {
      case BannerType.error:
        return Icons.error_outline;
      case BannerType.success:
        return Icons.check_circle_outline;
      case BannerType.info:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: _fgColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, color: _fgColor, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.callout.copyWith(color: _fgColor),
            ),
          ),
        ],
      ),
    );
  }
}
