import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_radius.dart';
import '../app_typography.dart';

/// Semantic tone of an [AppPill]. Maps to a (background, foreground) pair from
/// the active theme — see the LUMINA design system's Pill tone table.
enum AppPillTone { neutral, lumen, success, warning, danger }

/// Small status pill: a dot plus a label on a soft tinted background.
///
/// Used for invoice/stock statuses in list rows and for the sync chip. The dot
/// carries a ring in the pill's own background colour so it reads as inset.
class AppPill extends StatelessWidget {
  const AppPill({
    super.key,
    required this.label,
    this.tone = AppPillTone.neutral,
    this.showDot = true,
  });

  final String label;
  final AppPillTone tone;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final (bg, fg) = switch (tone) {
      AppPillTone.neutral => (lum.g100, lum.g600),
      AppPillTone.lumen => (lum.accentSoft, lum.accentPress),
      AppPillTone.success => (lum.successSoft, lum.successText),
      AppPillTone.warning => (lum.warningSoft, lum.warningText),
      AppPillTone.danger => (lum.dangerSoft, lum.dangerText),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: fg,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: bg, blurRadius: 0, spreadRadius: 2)],
              ),
            ),
            const SizedBox(width: 7),
          ],
          Text(
            label,
            style: AppTypography.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
