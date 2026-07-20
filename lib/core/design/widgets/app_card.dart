import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_radius.dart';
import '../app_spacing.dart';
import '../clay.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.raised = false,
  });

  final Widget child;
  final EdgeInsets? padding;

  /// When set, the card becomes tappable with a ripple clipped to its radius.
  final VoidCallback? onTap;

  /// Raised clay (stronger drop) vs the default soft clay.
  final bool raised;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final radius = BorderRadius.circular(AppRadius.lg);
    final content = ClayContainer(
      variant: raised ? ClayVariant.raised : ClayVariant.soft,
      color: lum.surface,
      borderRadius: AppRadius.lg,
      isDark: lum.isDark,
      padding: padding ?? const EdgeInsets.all(AppSpacing.xl),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: content,
      ),
    );
  }
}
