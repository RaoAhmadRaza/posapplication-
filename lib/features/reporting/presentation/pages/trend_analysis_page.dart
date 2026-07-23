import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_filter_chips.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/reporting.dart';
import '../controllers/reporting_controllers.dart';
import '../widgets/report_export_button.dart';
import '../widgets/reporting_line_chart.dart';
import '../widgets/reporting_stat_card.dart';

String _isoDay(DateTime d) => d.toIso8601String().substring(0, 10);

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
String _shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

const _rangeDays = [7, 30, 90];

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
    final lum = context.lum;
    final async = ref.watch(dailySalesProvider(_range));
    return AppDetailScaffold(
      eyebrow: 'Reports',
      title: 'Trend analysis',
      description: 'Revenue and profit over your selected range.',
      actions: [
        ReportExportButton(
          title: 'Sales Trend',
          headers: const ['Date', 'Revenue', 'Profit', 'Invoices'],
          rowsBuilder: () {
            final rows = ref.read(dailySalesProvider(_range)).value ?? [];
            return rows
                .map((r) => [
                      r.saleDate.toIso8601String().substring(0, 10),
                      r.totalRevenue.toStringAsFixed(2),
                      r.totalProfit.toStringAsFixed(2),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: AppFilterChips(
                labels: [for (final d in _rangeDays) '$d days'],
                selected: _rangeDays.indexOf(_days),
                onSelected: (i) => setState(() => _days = _rangeDays[i]),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const AppErrorState(
                title: 'Couldn’t load the report',
                body: 'We couldn’t reach the server. Please try again.',
              ),
              data: (rows) => rows.isEmpty
                  ? const AppEmptyState(
                      icon: LucideIcons.activity,
                      title: 'No sales in range',
                      body: 'Pick a wider range or make a sale to see trends.',
                    )
                  : _content(context, rows),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, List<DailySalesRow> rows) {
    final lum = context.lum;
    final totalRev = rows.fold<double>(0, (a, r) => a + r.totalRevenue);
    final totalProfit = rows.fold<double>(0, (a, r) => a + r.totalProfit);

    final revenue = [
      for (var i = 0; i < rows.length; i++)
        FlSpot(i.toDouble(), rows[i].totalRevenue),
    ];
    final profit = [
      for (var i = 0; i < rows.length; i++)
        FlSpot(i.toDouble(), rows[i].totalProfit),
    ];

    final labelIdx = <int>{
      0,
      (rows.length * 0.25).round(),
      (rows.length * 0.5).round(),
      (rows.length * 0.75).round(),
      rows.length - 1,
    }.where((i) => i >= 0 && i < rows.length).toList()
      ..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReportingStatGrid(
          minTileWidth: 200,
          cards: [
            ReportingStatCard(
              label: 'Total revenue · ${_days}d',
              icon: LucideIcons.trendingUp,
              iconColor: lum.accent,
              value: AppMoneyText(totalRev, size: 25),
            ),
            ReportingStatCard(
              label: 'Total profit · ${_days}d',
              icon: LucideIcons.coins,
              iconColor: lum.success,
              value: AppMoneyText(totalProfit, size: 25, color: lum.successText),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppSectionCard(
          eyebrow: 'Revenue & profit',
          trailing: _Legend(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ReportingLineChart(
                series: [
                  ReportingLineSeries(
                      spots: revenue, color: lum.accent, fill: true),
                  ReportingLineSeries(spots: profit, color: lum.success),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final i in labelIdx)
                    Text(
                      _shortDate(rows[i].saleDate),
                      style: AppTypography.caption.copyWith(color: lum.g500),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    Widget item(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 3,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 7),
            Text(label,
                style: AppTypography.caption.copyWith(color: lum.g600)),
          ],
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        item(lum.accent, 'Revenue'),
        const SizedBox(width: 16),
        item(lum.success, 'Profit'),
      ],
    );
  }
}
