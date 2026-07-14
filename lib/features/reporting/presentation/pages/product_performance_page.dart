import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../controllers/reporting_controllers.dart';
import '../../domain/entities/reporting.dart';

/// Metric used to sort/chart the product-performance rows.
enum _SortMetric {
  revenue('Revenue'),
  profit('Profit'),
  units('Units');

  const _SortMetric(this.label);
  final String label;

  double value(ProductPerformanceRow r) => switch (this) {
        _SortMetric.revenue => r.revenue,
        _SortMetric.profit => r.profit,
        _SortMetric.units => r.unitsSold,
      };
}

/// How many products the top-section bar chart shows.
const _kTopCount = 8;

class ProductPerformancePage extends ConsumerStatefulWidget {
  const ProductPerformancePage({super.key});

  @override
  ConsumerState<ProductPerformancePage> createState() =>
      _ProductPerformancePageState();
}

class _ProductPerformancePageState
    extends ConsumerState<ProductPerformancePage> {
  _SortMetric _metric = _SortMetric.revenue;

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
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final rowsAsync = ref.watch(productPerformanceProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text('Product Performance', style: AppTypography.largeTitle),
      ),
      body: rowsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ListView(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          children: [
            const SizedBox(height: AppSpacing.xxl),
            AppInlineBanner(
              message: 'Could not load report.',
              type: BannerType.error,
            ),
          ],
        ),
        data: (rows) => _buildBody(context, rows),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<ProductPerformanceRow> rows) {
    if (rows.isEmpty) {
      return Center(
        child: Text(
          'Nothing to show.',
          style: AppTypography.subhead.copyWith(color: AppColors.textMuted),
        ),
      );
    }

    final sorted = [...rows]
      ..sort((a, b) => _metric.value(b).compareTo(_metric.value(a)));
    final top = sorted.take(_kTopCount).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      children: [
        const SizedBox(height: AppSpacing.md),
        _SortSelector(
          selected: _metric,
          onChanged: (m) => setState(() => _metric = m),
        ),
        const SizedBox(height: AppSpacing.xl),
        _TopProductsChart(rows: top, metric: _metric),
        const SizedBox(height: AppSpacing.xxl),
        Text('All Products', style: AppTypography.title2),
        const SizedBox(height: AppSpacing.md),
        ...sorted.map((r) => _ProductRow(row: r)),
        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }
}

class _SortSelector extends StatelessWidget {
  const _SortSelector({required this.selected, required this.onChanged});

  final _SortMetric selected;
  final ValueChanged<_SortMetric> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final m in _SortMetric.values)
          ChoiceChip(
            label: Text(m.label),
            selected: m == selected,
            onSelected: (_) => onChanged(m),
            showCheckmark: false,
            backgroundColor: AppColors.background,
            selectedColor: AppColors.accent.withValues(alpha: 0.12),
            side: BorderSide(
              color: m == selected ? AppColors.accent : AppColors.separator,
              width: 0.5,
            ),
            labelStyle: AppTypography.footnote.copyWith(
              color: m == selected ? AppColors.accent : AppColors.textMuted,
              fontWeight: m == selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
      ],
    );
  }
}

class _TopProductsChart extends StatelessWidget {
  const _TopProductsChart({required this.rows, required this.metric});

  final List<ProductPerformanceRow> rows;
  final _SortMetric metric;

  @override
  Widget build(BuildContext context) {
    final maxY = rows.isEmpty
        ? 100.0
        : rows.map(metric.value).reduce((a, b) => a > b ? a : b) * 1.2;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Products · ${metric.label}',
              style: AppTypography.headline),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY > 0 ? maxY : 100,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, _, rod, _) {
                      return BarTooltipItem(
                        metric == _SortMetric.units
                            ? rod.toY.toStringAsFixed(0)
                            : formatPkr(rod.toY),
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= rows.length) {
                          return const SizedBox();
                        }
                        final r = rows[idx];
                        final label = r.sku ?? r.productName;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            width: 48,
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textHint),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (val, _) {
                        return Text(
                          val.toStringAsFixed(0),
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textHint),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval:
                      maxY > 0 ? (maxY / 4).ceilToDouble() : 25,
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(rows.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: metric.value(rows[i]),
                        color: AppColors.accent,
                        width: 18,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.row});
  final ProductPerformanceRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.productName,
                  style: AppTypography.headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (row.sku != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    row.sku!,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatPkr(row.revenue),
                style: AppTypography.headline
                    .copyWith(color: AppColors.accent),
              ),
              const SizedBox(height: 2),
              Text(
                'profit ${formatPkr(row.profit)} · units ${row.unitsSold.toStringAsFixed(0)}',
                style:
                    AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
