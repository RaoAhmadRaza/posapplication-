import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_motion.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_money_text.dart';

/// Direction of a KPI's change, and whether that direction is good news.
/// A falling receivables figure is positive; a rising low-stock count is not.
enum KpiTrend { up, down, none }

/// One KPI card: label + icon, the figure, and a sub-line that is either a
/// real trend delta or a static description of the figure.
class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.subLabel,
    this.isCount = false,
    this.trend = KpiTrend.none,
    this.trendIsGood = true,
    this.dimmed = false,
    this.editFooter,
  });

  final String label;
  final double value;
  final IconData icon;
  final Color iconColor;
  final String subLabel;
  final bool isCount;
  final KpiTrend trend;

  /// Whether [trend]'s direction should read as positive.
  final bool trendIsGood;

  /// Hidden-in-edit-mode tiles stay visible but recede.
  final bool dimmed;

  /// Per-tile visibility/reorder controls, shown only in edit mode.
  final Widget? editFooter;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final subColor = switch (trend) {
      KpiTrend.none => lum.g500,
      _ => trendIsGood ? lum.success : lum.danger,
    };
    final arrow = switch (trend) {
      KpiTrend.up => '▲ ',
      KpiTrend.down => '▼ ',
      KpiTrend.none => '',
    };

    return AnimatedOpacity(
      opacity: dimmed ? 0.42 : 1,
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      child: ClayContainer(
        variant: ClayVariant.raised,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lum.surface, lum.g100],
        ),
        borderRadius: AppRadius.lg,
        isDark: lum.isDark,
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: lum.g500,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(icon, size: 17, color: iconColor),
              ],
            ),
            const SizedBox(height: 11),
            if (isCount)
              Text(
                value.toStringAsFixed(0),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.monoValue.copyWith(
                  fontSize: 24,
                  letterSpacing: -0.48,
                  color: lum.textPrimary,
                ),
              )
            else
              AppMoneyText(value, size: 21),
            const SizedBox(height: 5),
            Text(
              '$arrow$subLabel',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: subColor,
              ),
            ),
            ?editFooter,
          ],
        ),
      ),
    );
  }
}

/// The per-tile edit controls: hide/show plus move up/down.
class KpiEditFooter extends StatelessWidget {
  const KpiEditFooter({
    super.key,
    required this.visible,
    required this.onToggle,
    required this.onUp,
    required this.onDown,
  });

  final bool visible;
  final VoidCallback onToggle;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.only(top: 11),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: lum.hairline)),
      ),
      child: Row(
        children: [
          _EditButton(
            icon: visible ? LucideIcons.eye : LucideIcons.eyeOff,
            tooltip: visible ? 'Hide card' : 'Show card',
            background: visible ? lum.accentSoft : lum.surface2,
            foreground: visible ? lum.accent : lum.g500,
            onPressed: onToggle,
          ),
          const Spacer(),
          _EditButton(
            icon: LucideIcons.chevronUp,
            tooltip: 'Move up',
            background: lum.surface2,
            foreground: lum.g600,
            onPressed: onUp,
          ),
          const SizedBox(width: 6),
          _EditButton(
            icon: LucideIcons.chevronDown,
            tooltip: 'Move down',
            background: lum.surface2,
            foreground: lum.g600,
            onPressed: onDown,
          ),
        ],
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({
    required this.icon,
    required this.tooltip,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 17, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}
