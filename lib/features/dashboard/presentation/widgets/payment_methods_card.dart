import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import 'dashboard_section_card.dart';

/// Payment-method split as a donut plus a legend.
///
/// Keeps fl_chart: a donut with a centre label is exactly what PieChart does
/// well, and the existing implementation already worked.
class PaymentMethodsCard extends StatelessWidget {
  const PaymentMethodsCard({super.key, required this.breakdown});

  final Map<String, double> breakdown;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    // Design palette first; the tail keeps tenants with many methods readable.
    final palette = [
      lum.accent,
      lum.beam,
      lum.warning,
      lum.success,
      lum.danger,
      lum.accentPress,
      lum.g400,
    ];

    final entries = breakdown.entries.toList();
    final total = entries.fold<double>(0, (sum, e) => sum + e.value);

    if (entries.isEmpty || total <= 0) {
      return DashboardSectionCard(
        title: 'Payment methods',
        child: SizedBox(
          height: 152,
          child: Center(
            child: Text(
              'No payments recorded yet',
              style: AppTypography.footnote.copyWith(color: lum.g500),
            ),
          ),
        ),
      );
    }

    return DashboardSectionCard(
      title: 'Payment methods',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 0,
                    centerSpaceRadius: 34,
                    startDegreeOffset: -90,
                    sections: [
                      for (var i = 0; i < entries.length; i++)
                        PieChartSectionData(
                          value: entries[i].value,
                          radius: 16,
                          color: palette[i % palette.length],
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _abbreviate(total),
                      style: AppTypography.title3.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: lum.textPrimary,
                      ),
                    ),
                    Text(
                      'SALES',
                      style: AppTypography.caption.copyWith(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.68,
                        color: lum.g500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0) const SizedBox(height: 9),
                  _LegendRow(
                    color: palette[i % palette.length],
                    label: entries[i].key,
                    percent: total > 0 ? entries[i].value / total * 100 : 0,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Compact centre label: 1.2m / 284k / 940.
  static String _abbreviate(double v) {
    final abs = v.abs();
    if (abs >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}m';
    if (abs >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.percent,
  });

  final Color color;
  final String label;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.footnote.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: lum.g700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${percent.toStringAsFixed(0)}%',
          style: AppTypography.monoValue.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: lum.textPrimary,
          ),
        ),
      ],
    );
  }
}
