import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';

/// One bar in a [ReportingBarChart].
@immutable
class ReportingBar {
  const ReportingBar({
    required this.label,
    required this.value,
    required this.valueLabel,
    this.color,
  });

  final String label;
  final double value;

  /// Text drawn above the bar (already abbreviated, e.g. '5.2M').
  final String valueLabel;

  /// Bar fill; defaults to the accent when null.
  final Color? color;
}

/// The design's report bar chart: rounded single-colour rods with the value
/// sitting above each bar (rendered by fl_chart's own tooltip so the label
/// tracks the rod, never the container) and category labels below a hairline
/// baseline. Restyled fl_chart — no gridbox, no y-axis.
class ReportingBarChart extends StatelessWidget {
  const ReportingBarChart({
    super.key,
    required this.bars,
    this.height = 210,
    this.barWidth = 18,
  });

  final List<ReportingBar> bars;
  final double height;
  final double barWidth;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;

    if (bars.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No data to chart.',
            style: AppTypography.footnote.copyWith(color: lum.g500),
          ),
        ),
      );
    }

    final maxV = bars.map((b) => b.value).reduce((a, b) => a > b ? a : b);
    final maxY = maxV > 0 ? maxV * 1.25 : 1.0;
    final labelStyle =
        AppTypography.caption.copyWith(fontSize: 11, color: lum.g500);
    final valueStyle = TextStyle(
      fontFamily: AppTypography.mono,
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      color: lum.g600,
    );

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(
            enabled: false,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.transparent,
              tooltipPadding: EdgeInsets.zero,
              tooltipMargin: 4,
              getTooltipItem: (group, _, _, _) =>
                  BarTooltipItem(bars[group.x].valueLabel, valueStyle),
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (val, _) {
                  final i = val.toInt();
                  if (i < 0 || i >= bars.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: 60,
                      child: Text(
                        bars[i].label,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: labelStyle,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(
            show: true,
            border: Border(bottom: BorderSide(color: lum.hairline)),
          ),
          barGroups: [
            for (var i = 0; i < bars.length; i++)
              BarChartGroupData(
                x: i,
                showingTooltipIndicators: const [0],
                barRods: [
                  BarChartRodData(
                    toY: bars[i].value,
                    color: bars[i].color ?? lum.accent,
                    width: barWidth,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
