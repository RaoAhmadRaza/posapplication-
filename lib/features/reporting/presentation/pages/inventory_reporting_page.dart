import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/reporting.dart';
import '../controllers/reporting_controllers.dart';
import '../widgets/report_export_button.dart';

class InventoryReportingPage extends ConsumerWidget {
  const InventoryReportingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text('Inventory', style: AppTypography.largeTitle),
        actions: [
          ReportExportButton(
            title: 'Inventory Valuation',
            headers: const [
              'Product',
              'SKU',
              'Category',
              'Qty',
              'Avg Cost',
              'Total Value',
              'Retail Value',
              'Below Reorder',
            ],
            rowsBuilder: () {
              final rows = ref.read(inventoryValuationProvider).value ?? [];
              return rows
                  .map((r) => [
                        r.productName,
                        r.sku ?? '',
                        r.categoryName ?? '',
                        r.qtyOnHand.toStringAsFixed(0),
                        r.avgCost.toStringAsFixed(2),
                        r.totalValue.toStringAsFixed(2),
                        r.retailValue.toStringAsFixed(2),
                        r.belowReorder ? 'Yes' : 'No',
                      ])
                  .toList();
            },
          ),
        ],
      ),
      body: PermissionGate(
        module: 'reports',
        action: 'read',
        fallback: Center(
          child: Text(
            'No access to reports.',
            style: AppTypography.subhead.copyWith(color: AppColors.textMuted),
          ),
        ),
        child: _buildBody(ref),
      ),
    );
  }

  Widget _buildBody(WidgetRef ref) {
    final rows = ref.watch(inventoryValuationProvider);
    return rows.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: AppInlineBanner(
          message: 'Could not load report.',
          type: BannerType.error,
        ),
      ),
      data: (data) {
        if (data.isEmpty) {
          return Center(
            child: Text(
              'Nothing to show.',
              style: AppTypography.subhead.copyWith(color: AppColors.textMuted),
            ),
          );
        }
        return _ReportList(rows: data);
      },
    );
  }
}

class _ReportList extends StatelessWidget {
  const _ReportList({required this.rows});
  final List<InventoryValuationRow> rows;

  @override
  Widget build(BuildContext context) {
    final totalValue = rows.fold<double>(0, (sum, r) => sum + r.totalValue);
    final retailValue = rows.fold<double>(0, (sum, r) => sum + r.retailValue);
    final belowReorder = rows.where((r) => r.belowReorder).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      children: [
        const SizedBox(height: AppSpacing.xs),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Stock Value',
                style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                formatPkr(totalValue),
                style: AppTypography.title1.copyWith(color: AppColors.accent),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Retail: ${formatPkr(retailValue)}',
                style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _CategoryChart(rows: rows),
        const SizedBox(height: AppSpacing.xxl),
        Text('Below Reorder', style: AppTypography.title2),
        const SizedBox(height: AppSpacing.md),
        if (belowReorder.isEmpty)
          Text(
            'All stock above reorder.',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          )
        else
          ...belowReorder.map((r) => _ReorderRow(row: r)),
        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }
}

class _CategoryChart extends StatelessWidget {
  const _CategoryChart({required this.rows});
  final List<InventoryValuationRow> rows;

  @override
  Widget build(BuildContext context) {
    final byCategory = <String, double>{};
    for (final r in rows) {
      final key = r.categoryName ?? 'Uncategorized';
      byCategory[key] = (byCategory[key] ?? 0) + r.totalValue;
    }
    final entries = byCategory.entries.toList();
    final maxY = entries.isEmpty
        ? 100.0
        : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Value by Category', style: AppTypography.headline),
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
                        formatPkr(rod.toY),
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
                      reservedSize: 44,
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= entries.length) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            width: 56,
                            child: Text(
                              entries[idx].key,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
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
                barGroups: List.generate(entries.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: entries[i].value,
                        color: AppColors.accent,
                        width: 18,
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(4)),
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

class _ReorderRow extends StatelessWidget {
  const _ReorderRow({required this.row});
  final InventoryValuationRow row;

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
                Text(row.productName, style: AppTypography.headline),
                if (row.sku != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    row.sku ?? '',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            '${row.qtyOnHand.toStringAsFixed(0)} / '
            '${row.reorderPoint.toStringAsFixed(0)}',
            style: AppTypography.headline.copyWith(color: AppColors.destructive),
          ),
        ],
      ),
    );
  }
}
