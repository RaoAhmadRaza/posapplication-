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
String _isoDay(DateTime d) => d.toIso8601String().substring(0, 10);

class TrendAnalysisPage extends ConsumerStatefulWidget {
  const TrendAnalysisPage({super.key});

  @override
  ConsumerState<TrendAnalysisPage> createState() => _TrendAnalysisPageState();
}

class _TrendAnalysisPageState extends ConsumerState<TrendAnalysisPage> {
  int _days = 30;

  TrendRange get _range {
    final to = DateTime.now();
    final from = to.subtract(Duration(days: _days - 1));
    return (from: _isoDay(from), to: _isoDay(to));
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      module: 'reports',
      action: 'read',
      fallback: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text(
            'No access to reports.',
            style: AppTypography.subhead.copyWith(color: AppColors.textMuted),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
          title: Text('Trends', style: AppTypography.largeTitle),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final rows = ref.watch(dailySalesProvider(_range));
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      children: [
        const SizedBox(height: AppSpacing.xs),
        _RangeSelector(days: _days, onSelect: (d) => setState(() => _days = d)),
        const SizedBox(height: AppSpacing.xl),
        rows.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xxl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => AppInlineBanner(
            message: 'Could not load report.',
            type: BannerType.error,
          ),
          data: (data) => _buildData(data),
        ),
        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }

  Widget _buildData(List<DailySalesRow> rows) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xxl),
        child: Center(
          child: Text(
            'No sales in range.',
            style: AppTypography.subhead.copyWith(color: AppColors.textMuted),
          ),
        ),
      );
    }

    final totalRevenue = rows.fold<double>(0, (a, r) => a + r.totalRevenue);
    final totalProfit = rows.fold<double>(0, (a, r) => a + r.totalProfit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: _Headline(
                  label: 'Total Revenue',
                  value: formatPkr(totalRevenue),
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _Headline(
                  label: 'Total Profit',
                  value: formatPkr(totalProfit),
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _RevenueProfitChart(rows: rows),
      ],
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.days, required this.onSelect});
  final int days;
  final ValueChanged<int> onSelect;

  static const _options = [7, 30, 90];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final d in _options)
          ChoiceChip(
            label: Text('${d}d'),
            selected: days == d,
            onSelected: (_) => onSelect(d),
          ),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(value, style: AppTypography.title2.copyWith(color: color)),
      ],
    );
  }
}

class _RevenueProfitChart extends StatelessWidget {
  const _RevenueProfitChart({required this.rows});
  final List<DailySalesRow> rows;

  @override
  Widget build(BuildContext context) {
    final maxY = rows
            .map((r) => r.totalRevenue > r.totalProfit ? r.totalRevenue : r.totalProfit)
            .fold<double>(0, (a, b) => a > b ? a : b) *
        1.2;
    final labelStep = (rows.length / 6).ceil().clamp(1, rows.length);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Revenue & Profit', style: AppTypography.headline),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (rows.length - 1).toDouble(),
                minY: 0,
                maxY: maxY > 0 ? maxY : 100,
                lineTouchData: const LineTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: labelStep.toDouble(),
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= rows.length) {
                          return const SizedBox();
                        }
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
                  _series((r) => r.totalRevenue, AppColors.accent),
                  _series((r) => r.totalProfit, AppColors.success),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _Legend(color: AppColors.accent, label: 'Revenue'),
              const SizedBox(width: AppSpacing.base),
              _Legend(color: AppColors.success, label: 'Profit'),
            ],
          ),
        ],
      ),
    );
  }

  LineChartBarData _series(double Function(DailySalesRow) pick, Color color) {
    return LineChartBarData(
      spots: [
        for (var i = 0; i < rows.length; i++)
          FlSpot(i.toDouble(), pick(rows[i])),
      ],
      color: color,
      barWidth: 2,
      isCurved: false,
      dotData: const FlDotData(show: false),
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
