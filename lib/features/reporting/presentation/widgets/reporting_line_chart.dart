import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/design/app_colors.dart';

/// One line in a [ReportingLineChart]. The caller builds the [spots] (so a
/// projection series can start where the actual series ends).
@immutable
class ReportingLineSeries {
  const ReportingLineSeries({
    required this.spots,
    required this.color,
    this.dashed = false,
    this.fill = false,
  });

  final List<FlSpot> spots;
  final Color color;

  /// Dashed stroke (used for the forecast projection).
  final bool dashed;

  /// Soft 10% area fill under the line (used for the primary revenue line).
  final bool fill;
}

/// The design's report line chart: thin strokes over faint horizontal
/// gridlines, an optional soft area fill, and an optional projection split — a
/// shaded future region plus a dashed vertical rule. Restyled fl_chart; no
/// axes (the page renders its own x labels below).
class ReportingLineChart extends StatelessWidget {
  const ReportingLineChart({
    super.key,
    required this.series,
    this.height = 240,
    this.projectionSplitX,
  });

  final List<ReportingLineSeries> series;
  final double height;

  /// When set, x-values at or beyond this get the projection treatment: a
  /// [beamSoft] shaded region and a dashed vertical divider.
  final double? projectionSplitX;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final allSpots = [for (final s in series) ...s.spots];
    final maxX = allSpots.isEmpty
        ? 1.0
        : allSpots.map((s) => s.x).reduce((a, b) => a > b ? a : b);
    final peakY = allSpots.isEmpty
        ? 1.0
        : allSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final maxY = peakY > 0 ? peakY * 1.15 : 1.0;
    final split = projectionSplitX;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX > 0 ? maxX : 1,
          minY: 0,
          maxY: maxY,
          lineTouchData: const LineTouchData(enabled: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: lum.hairline, strokeWidth: 1),
          ),
          rangeAnnotations: split == null
              ? const RangeAnnotations()
              : RangeAnnotations(
                  verticalRangeAnnotations: [
                    VerticalRangeAnnotation(
                      x1: split,
                      x2: maxX,
                      color: lum.beamSoft.withValues(alpha: 0.5),
                    ),
                  ],
                ),
          extraLinesData: split == null
              ? const ExtraLinesData()
              : ExtraLinesData(
                  verticalLines: [
                    VerticalLine(
                      x: split,
                      color: lum.g300,
                      strokeWidth: 1,
                      dashArray: const [3, 3],
                    ),
                  ],
                ),
          lineBarsData: [
            for (final s in series)
              LineChartBarData(
                spots: s.spots,
                color: s.color,
                barWidth: 2.5,
                isCurved: false,
                dashArray: s.dashed ? const [5, 4] : null,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: s.fill,
                  color: s.color.withValues(alpha: 0.10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
