import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_filter_chips.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../controllers/reporting_controllers.dart';
import '../../domain/entities/reporting.dart';
import '../widgets/report_export_button.dart';
import '../widgets/reporting_bar_chart.dart';
import '../widgets/reporting_ui.dart';

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
    final lum = context.lum;
    final async = ref.watch(productPerformanceProvider);
    return AppDetailScaffold(
      eyebrow: 'Reports',
      title: 'Product performance',
      description: 'Top movers by revenue, profit or units sold.',
      actions: [
        ReportExportButton(
          title: 'Product Performance',
          headers: const ['Product', 'SKU', 'Units', 'Revenue', 'Profit', 'Invoices'],
          rowsBuilder: () {
            final rows = ref.read(productPerformanceProvider).value ?? [];
            final sorted = [...rows]
              ..sort((a, b) => _metric.value(b).compareTo(_metric.value(a)));
            return sorted
                .map((r) => [
                      r.productName,
                      r.sku ?? '',
                      r.unitsSold.toStringAsFixed(0),
                      r.revenue.toStringAsFixed(2),
                      r.profit.toStringAsFixed(2),
                      r.invoiceCount.toString(),
                    ])
                .toList();
          },
        ),
      ],
      child: PermissionGate(
        module: 'reports',
        action: 'read',
        fallback: Center(
          child: Text(
            'You don’t have access to reports.',
            style: AppTypography.subhead.copyWith(color: lum.g500),
          ),
        ),
        child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xxxl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const AppErrorState(
            title: 'Unable to load the report',
            body: 'We couldn’t reach the server. Please try again.',
          ),
          data: (rows) => rows.isEmpty
              ? const AppEmptyState(
                  icon: LucideIcons.trendingUp,
                  title: 'Nothing to show',
                  body: 'Product figures appear here once you’ve made sales.',
                )
              : _content(context, rows),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, List<ProductPerformanceRow> rows) {
    final lum = context.lum;
    final sorted = [...rows]
      ..sort((a, b) => _metric.value(b).compareTo(_metric.value(a)));
    final top = sorted.take(_kTopCount).toList();
    final muted = Color.lerp(lum.accent, lum.surface, 0.5)!;

    final bars = [
      for (var i = 0; i < top.length; i++)
        ReportingBar(
          label: top[i].sku ?? top[i].productName,
          value: _metric.value(top[i]),
          valueLabel: abbreviateNum(_metric.value(top[i])),
          color: i == 0 ? lum.accent : muted,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: AppFilterChips(
            labels: [for (final m in _SortMetric.values) m.label],
            selected: _SortMetric.values.indexOf(_metric),
            onSelected: (i) =>
                setState(() => _metric = _SortMetric.values[i]),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppSectionCard(
          eyebrow: 'Top $_kTopCount by ${_metric.label.toLowerCase()}',
          child: ReportingBarChart(bars: bars),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          padding: EdgeInsets.zero,
          child: LayoutBuilder(
            builder: (context, c) {
              final width = c.maxWidth < 560 ? 560.0 : c.maxWidth;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  child: Column(
                    children: [
                      _HeaderRow(),
                      for (final r in sorted) _ProductRow(row: r),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

const _cols = [2.2, 1.0, 1.2, 1.2, 0.9];

class _HeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final style = AppTypography.caption.copyWith(
      fontSize: 11,
      letterSpacing: 0.5,
      fontWeight: FontWeight.w700,
      color: lum.g500,
    );
    Widget cell(int i, String label, {bool right = true}) => Expanded(
          flex: (_cols[i] * 10).round(),
          child: Text(
            label.toUpperCase(),
            textAlign: right && i > 0 ? TextAlign.right : TextAlign.left,
            style: style,
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: lum.g100,
        border: Border(bottom: BorderSide(color: lum.hairline)),
      ),
      child: Row(
        children: [
          cell(0, 'Product'),
          cell(1, 'Units'),
          cell(2, 'Revenue'),
          cell(3, 'Profit'),
          cell(4, 'Invoices'),
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
    final lum = context.lum;
    final mono = TextStyle(
      fontFamily: AppTypography.mono,
      fontSize: 13.5,
      color: lum.textPrimary,
    );
    Widget num(int i, String text, {Color? color}) => Expanded(
          flex: (_cols[i] * 10).round(),
          child: Text(
            text,
            textAlign: TextAlign.right,
            style: mono.copyWith(color: color ?? lum.textPrimary),
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: lum.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: (_cols[0] * 10).round(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(color: lum.textPrimary),
                ),
                if (row.sku != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    row.sku!,
                    style: TextStyle(
                      fontFamily: AppTypography.mono,
                      fontSize: 11.5,
                      color: lum.g500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          num(1, row.unitsSold.toStringAsFixed(0)),
          num(2, formatAmount(row.revenue, decimals: 0)),
          num(3, formatAmount(row.profit, decimals: 0), color: lum.successText),
          num(4, '${row.invoiceCount}', color: lum.g600),
        ],
      ),
    );
  }
}
