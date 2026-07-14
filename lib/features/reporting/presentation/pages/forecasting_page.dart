import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/reporting.dart';
import '../controllers/reporting_controllers.dart';

/// yyyy-MM-dd for the daily-sales range params.
String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

/// Trailing window + projection horizon (days).
const _historyDays = 60;
const _windowDays = 7;
const _projectDays = 7;

class ForecastingPage extends ConsumerWidget {
  const ForecastingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final from = _iso(today.subtract(const Duration(days: _historyDays - 1)));
    final range = (from: from, to: _iso(today));

    return PermissionGate(
      module: 'reports',
      action: 'read',
      fallback: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text(
            'No access.',
            style: AppTypography.subhead.copyWith(color: AppColors.textMuted),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
          title: Text('Forecasting', style: AppTypography.largeTitle),
        ),
        body: ref.watch(dailySalesProvider(range)).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => ListView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                children: [
                  AppInlineBanner(
                    message: 'Could not load forecast.',
                    type: BannerType.error,
                  ),
                ],
              ),
              data: (rows) => _buildBody(rows),
            ),
      ),
    );
  }

  Widget _buildBody(List<DailySalesRow> rows) {
    if (rows.length < 2) {
      return Center(
        child: Text(
          'Not enough data to forecast.',
          style: AppTypography.subhead.copyWith(color: AppColors.textMuted),
        ),
      );
    }

    final revenue = [for (final r in rows) r.totalRevenue];
    final projected = _trailingAverage(revenue, _windowDays);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      children: [
        const SizedBox(height: AppSpacing.xs),
        AppInlineBanner(
          message:
              'Estimate — 7-day moving-average projection. Not ML; for guidance only.',
          type: BannerType.info,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Projected daily revenue (next 7d avg)',
                style:
                    AppTypography.footnote.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                formatPkr(projected),
                style: AppTypography.title2.copyWith(color: AppColors.warning),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _ForecastChart(rows: rows, projected: projected),
        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }

  /// Mean of the last [window] entries (or all if fewer). Series is non-empty.
  double _trailingAverage(List<double> series, int window) {
    final start = series.length > window ? series.length - window : 0;
    final tail = series.sublist(start);
    final sum = tail.fold<double>(0, (a, b) => a + b);
    return sum / tail.length;
  }
}

class _ForecastChart extends StatelessWidget {
  const _ForecastChart({required this.rows, required this.projected});

  final List<DailySalesRow> rows;
  final double projected;

  @override
  Widget build(BuildContext context) {
    final n = rows.length;
    final lastActual = rows[n - 1].totalRevenue;

    // Historical revenue over x = 0..n-1.
    final history = [
      for (var i = 0; i < n; i++) FlSpot(i.toDouble(), rows[i].totalRevenue),
    ];
    // Projection over x = n-1..n-1+projectDays; anchored to last actual point
    // for a continuous line, then flat at the moving-average value.
    final forecast = [
      FlSpot((n - 1).toDouble(), lastActual),
      for (var i = 1; i <= _projectDays; i++)
        FlSpot((n - 1 + i).toDouble(), projected),
    ];

    final peak = [
      ...rows.map((r) => r.totalRevenue),
      projected,
    ].fold<double>(0, (a, b) => a > b ? a : b);
    final maxY = peak > 0 ? peak * 1.2 : 100.0;
    final maxX = (n - 1 + _projectDays).toDouble();
    final labelStep = ((n + _projectDays) / 6).ceil().clamp(1, n + _projectDays);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Revenue forecast', style: AppTypography.headline),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: maxX,
                minY: 0,
                maxY: maxY,
                lineTouchData: const LineTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: labelStep.toDouble(),
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= n) return const SizedBox();
                        final d = rows[idx].saleDate;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${d.day}/${d.month}',
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textHint),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (val, _) => Text(
                        val.toStringAsFixed(0),
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textHint),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 0 ? (maxY / 4).ceilToDouble() : 25,
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: history,
                    color: AppColors.accent,
                    barWidth: 2,
                    isCurved: false,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: forecast,
                    color: AppColors.warning,
                    barWidth: 2,
                    isCurved: false,
                    dashArray: const [6, 4],
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _Legend(color: AppColors.accent, label: 'Actual'),
              const SizedBox(width: AppSpacing.base),
              _Legend(color: AppColors.warning, label: 'Projected'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}
