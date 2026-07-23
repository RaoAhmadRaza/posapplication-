import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../domain/entities/reporting.dart';
import '../controllers/reporting_controllers.dart';
import '../widgets/report_export_button.dart';
import '../widgets/reporting_bar_chart.dart';
import '../widgets/reporting_stat_card.dart';
import '../widgets/reporting_ui.dart';

class InventoryReportingPage extends ConsumerWidget {
  const InventoryReportingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final async = ref.watch(inventoryValuationProvider);
    return AppDetailScaffold(
      eyebrow: 'Reports',
      title: 'Inventory report',
      description: 'Stock valuation and reorder health across the branch.',
      actions: [
        ReportExportButton(
          title: 'Inventory Valuation',
          headers: const [
            'Product', 'SKU', 'Category', 'Qty', 'Avg Cost', 'Total Value',
            'Retail Value', 'Below Reorder',
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
      child: PermissionGate(
        module: 'reports',
        action: 'read',
        fallback: _fallback(lum),
        child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xxxl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const AppErrorState(
            title: 'Couldn’t load the report',
            body: 'We couldn’t reach the server. Please try again.',
          ),
          data: (rows) => rows.isEmpty
              ? const AppEmptyState(
                  icon: LucideIcons.boxes,
                  title: 'Nothing to show',
                  body: 'Inventory figures will appear here once you hold stock.',
                )
              : _Content(rows: rows),
        ),
      ),
    );
  }

  Widget _fallback(LumColors lum) => Center(
        child: Text(
          'You don’t have access to reports.',
          style: AppTypography.subhead.copyWith(color: lum.g500),
        ),
      );
}

class _Content extends StatelessWidget {
  const _Content({required this.rows});
  final List<InventoryValuationRow> rows;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final totalCost = rows.fold<double>(0, (s, r) => s + r.totalValue);
    final retail = rows.fold<double>(0, (s, r) => s + r.retailValue);
    final belowReorder = rows.where((r) => r.belowReorder).toList();

    final byCategory = <String, double>{};
    for (final r in rows) {
      final k = r.categoryName ?? 'Uncategorized';
      byCategory[k] = (byCategory[k] ?? 0) + r.totalValue;
    }
    final bars = [
      for (final e in byCategory.entries)
        ReportingBar(
          label: e.key,
          value: e.value,
          valueLabel: abbreviateNum(e.value),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReportingStatGrid(
          cards: [
            ReportingStatCard(
              label: 'Stock value · cost',
              icon: LucideIcons.wallet,
              iconColor: lum.accent,
              value: AppMoneyText(totalCost, size: 25),
            ),
            ReportingStatCard(
              label: 'Retail value',
              icon: LucideIcons.tag,
              value: AppMoneyText(retail, size: 25),
            ),
            ReportingStatCard(
              label: 'Below reorder',
              icon: LucideIcons.triangleAlert,
              iconColor: lum.warning,
              value: ReportingStatValue('${belowReorder.length}',
                  color: lum.dangerText),
            ),
            ReportingStatCard(
              label: 'SKUs in stock',
              icon: LucideIcons.package,
              value: ReportingStatValue('${rows.length}'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppSectionCard(
          eyebrow: 'Stock value by category',
          child: ReportingBarChart(bars: bars),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppSectionCard(
          eyebrow: 'Below reorder point',
          padded: false,
          child: belowReorder.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    'All stock is above its reorder point.',
                    style: AppTypography.footnote.copyWith(color: lum.g500),
                  ),
                )
              : Column(
                  children: [
                    for (final r in belowReorder) _ReorderRow(row: r),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ReorderRow extends StatelessWidget {
  const _ReorderRow({required this.row});
  final InventoryValuationRow row;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: BoxDecoration(
        color: lum.dangerSoft,
        border: Border(top: BorderSide(color: lum.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.productName,
                  style: AppTypography.body.copyWith(color: lum.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  [row.sku, row.categoryName]
                      .whereType<String>()
                      .where((s) => s.isNotEmpty)
                      .join(' · '),
                  style: TextStyle(
                    fontFamily: AppTypography.mono,
                    fontSize: 11.5,
                    color: lum.g500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                row.qtyOnHand.toStringAsFixed(0),
                style: TextStyle(
                  fontFamily: AppTypography.mono,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: lum.dangerText,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'of ${row.reorderPoint.toStringAsFixed(0)} min',
                style: AppTypography.caption.copyWith(color: lum.g500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
