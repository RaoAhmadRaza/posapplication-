import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_pill.dart';

/// Shared presentation helpers for the reporting module. Pure display logic —
/// no data access, no business rules.

/// Abbreviates a number for a chart value label: 5.2M / 480k / 37.
String abbreviateNum(num v) {
  final n = v.abs();
  if (n >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
  if (n >= 1e3) return '${(v / 1e3).toStringAsFixed(0)}k';
  return v.toStringAsFixed(0);
}

/// Visual meta for a smart-insight recommendation type. Every real type the
/// backend can emit maps to a tone + icon + human label; unknown types fall
/// back to the generic Lumen "Insight" treatment rather than being dropped.
({AppPillTone tone, IconData icon, String label}) insightMeta(String type) {
  switch (type) {
    case 'REORDER':
      return (tone: AppPillTone.success, icon: LucideIcons.filePlus, label: 'Reorder');
    case 'PRICE':
      return (tone: AppPillTone.warning, icon: LucideIcons.percent, label: 'Pricing');
    case 'SLOW_MOVER':
      return (tone: AppPillTone.neutral, icon: LucideIcons.timer, label: 'Slow mover');
    case 'CASHFLOW':
      return (tone: AppPillTone.danger, icon: LucideIcons.banknote, label: 'Cash flow');
    default:
      return (tone: AppPillTone.lumen, icon: LucideIcons.sparkles, label: 'Insight');
  }
}

/// The (background, foreground) pair for a pill tone — mirrors [AppPill]'s own
/// table so an icon badge can share the same tinting.
(Color, Color) pillColors(LumColors lum, AppPillTone tone) => switch (tone) {
      AppPillTone.neutral => (lum.g100, lum.g600),
      AppPillTone.lumen => (lum.accentSoft, lum.accentPress),
      AppPillTone.success => (lum.successSoft, lum.successText),
      AppPillTone.warning => (lum.warningSoft, lum.warningText),
      AppPillTone.danger => (lum.dangerSoft, lum.dangerText),
      AppPillTone.transit => (lum.transitSoft, lum.transitText),
    };

/// The design's insight type badge: a tinted pill carrying the type's icon and
/// label (e.g. a green "Reorder" with a file-plus glyph).
class InsightBadge extends StatelessWidget {
  const InsightBadge({super.key, required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final meta = insightMeta(type);
    final (bg, fg) = pillColors(lum, meta.tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 13, color: fg),
          const SizedBox(width: 6),
          Text(
            meta.label,
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dot colour for a confidence score: high → success, mid → warning, low → grey.
Color confidenceColor(LumColors lum, double score) {
  if (score >= 0.85) return lum.success;
  if (score >= 0.70) return lum.warning;
  return lum.g400;
}

/// Status pill for an aging balance: Overdue past 60 days, else Current.
AppPill agingPill(int maxDaysOverdue) => maxDaysOverdue > 60
    ? const AppPill(label: 'Overdue', tone: AppPillTone.danger)
    : const AppPill(label: 'Current', tone: AppPillTone.neutral);
