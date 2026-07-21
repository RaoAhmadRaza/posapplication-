import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';

/// Panel used by the dashboard's chart and list sections: a soft clay card with
/// a display-face heading and an optional right-aligned eyebrow.
///
/// [padded] false lets a section run its own rows edge to edge (recent sales),
/// in which case the header keeps its own inset.
class DashboardSectionCard extends StatelessWidget {
  const DashboardSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.eyebrow,
    this.trailing,
    this.padded = true,
  });

  final String title;
  final Widget child;

  /// Small uppercase caption opposite the title (e.g. 'LAST 7 DAYS').
  final String? eyebrow;

  /// Interactive element opposite the title (e.g. a 'View all' button).
  final Widget? trailing;

  final bool padded;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final header = Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTypography.title3.copyWith(
              fontSize: 16,
              color: lum.textPrimary,
            ),
          ),
        ),
        if (eyebrow != null)
          Text(
            eyebrow!,
            style: AppTypography.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.66,
              color: lum.g500,
            ),
          ),
        ?trailing,
      ],
    );

    return ClayContainer(
      variant: ClayVariant.soft,
      color: lum.surface,
      borderRadius: AppRadius.lg,
      isDark: lum.isDark,
      padding: padded ? const EdgeInsets.all(18) : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (padded)
            header
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: header,
            ),
          if (padded) const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
