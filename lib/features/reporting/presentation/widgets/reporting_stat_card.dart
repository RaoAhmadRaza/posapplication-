import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';

/// The design's KPI stat card: a clay-raised tile with a subtle surface→g100
/// wash, a label + tinted icon top row, and a big display-face value.
///
/// [value] is a widget so callers pass an [AppMoneyText] for money or a plain
/// display-face number for counts.
class ReportingStatCard extends StatelessWidget {
  const ReportingStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor,
  });

  final String label;
  final Widget value;
  final IconData icon;

  /// Icon tint; defaults to the muted grey used for non-accent metrics.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return ClayContainer(
      variant: ClayVariant.raised,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lum.surface, lum.g100],
      ),
      borderRadius: AppRadius.lg,
      isDark: lum.isDark,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.footnote.copyWith(
                    fontWeight: FontWeight.w600,
                    color: lum.g500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 18, color: iconColor ?? lum.g500),
            ],
          ),
          const SizedBox(height: 14),
          value,
        ],
      ),
    );
  }
}

/// A count/label value styled in the display face, for stat cards that show a
/// number that is not money (SKU counts, entity counts).
class ReportingStatValue extends StatelessWidget {
  const ReportingStatValue(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Text(
      text,
      style: AppTypography.title1.copyWith(
        fontFamily: AppTypography.display,
        fontWeight: FontWeight.w700,
        fontSize: 25,
        letterSpacing: -0.5,
        color: color ?? lum.textPrimary,
      ),
    );
  }
}

/// Width-derived grid of stat cards: columns come from the available width
/// against [minTileWidth], never a hand-picked aspect ratio (tiles size to
/// their own content height).
class ReportingStatGrid extends StatelessWidget {
  const ReportingStatGrid({
    super.key,
    required this.cards,
    this.minTileWidth = 168,
    this.gap = 14,
  });

  final List<Widget> cards;
  final double minTileWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = (width / minTileWidth).floor().clamp(1, cards.length);
        final tileWidth = (width - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards) SizedBox(width: tileWidth, child: card),
          ],
        );
      },
    );
  }
}
