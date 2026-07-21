import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';

/// Centred icon + copy used wherever a sales surface has nothing to show.
///
/// Sections always render this instead of being dropped from the layout — a
/// vanished card reads as a rendering bug and silently widens its neighbour.
class SalesEmptyState extends StatelessWidget {
  const SalesEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.minHeight = 220,
    this.action,
  });

  final IconData icon;
  final String message;
  final double minHeight;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: lum.g300),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.footnote.copyWith(
                  height: 1.5,
                  color: lum.g500,
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: 16),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
