import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/reporting.dart';
import '../controllers/reporting_controllers.dart';
import '../widgets/reporting_line_chart.dart';
import '../widgets/reporting_stat_card.dart';

String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

const _historyDays = 60;
const _windowDays = 7;
const _projectDays = 7;

class ForecastingPage extends ConsumerWidget {
  const ForecastingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final today = DateTime.now();
    final from = _iso(today.subtract(const Duration(days: _historyDays - 1)));
    final range = (from: from, to: _iso(today));
    final async = ref.watch(dailySalesProvider(range));

    return AppDetailScaffold(
      eyebrow: 'Reports',
      title: 'Forecasting',
      description: 'A 7-day sales projection from recent activity.',
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
            title: 'Unable to load the forecast',
            body: 'We couldn’t reach the server. Please try again.',
          ),
          data: (rows) => rows.length < 2
              ? const AppEmptyState(
                  icon: LucideIcons.lineChart,
                  title: 'Not enough data to forecast',
                  body: 'A few more days of sales are needed to project a trend.',
                )
              : _content(context, rows),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, List<DailySalesRow> rows) {
    final lum = context.lum;
    final revenue = [for (final r in rows) r.totalRevenue];
    final projected = _trailingAverage(revenue, _windowDays);
    final projTotal = projected * _projectDays;

    final n = rows.length;
    final actual = [
      for (var i = 0; i < n; i++) FlSpot(i.toDouble(), rows[i].totalRevenue),
    ];
    final projection = [
      FlSpot((n - 1).toDouble(), rows[n - 1].totalRevenue),
      for (var k = 1; k <= _projectDays; k++)
        FlSpot((n - 1 + k).toDouble(), projected),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppInlineBanner(
          type: BannerType.info,
          message: 'A rules-based projection — a 7-day moving average over the '
              'last 60 days, extended 7 days ahead. A guide, not an ML forecast.',
        ),
        const SizedBox(height: AppSpacing.xl),
        ReportingStatGrid(
          minTileWidth: 200,
          cards: [
            ReportingStatCard(
              label: 'Projected · next 7 days',
              icon: LucideIcons.lineChart,
              iconColor: lum.beam,
              value: AppMoneyText(projTotal, size: 25),
            ),
            ReportingStatCard(
              label: 'Avg daily · projected',
              icon: LucideIcons.activity,
              value: AppMoneyText(projected, size: 25),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppSectionCard(
          eyebrow: 'Daily revenue & projection',
          trailing: _Legend(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ReportingLineChart(
                projectionSplitX: (n - 1).toDouble(),
                series: [
                  ReportingLineSeries(
                      spots: actual, color: lum.accent, fill: true),
                  ReportingLineSeries(
                      spots: projection, color: lum.beam, dashed: true),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('60 days ago',
                      style:
                          AppTypography.caption.copyWith(color: lum.g500)),
                  Text('today',
                      style:
                          AppTypography.caption.copyWith(color: lum.g500)),
                  Text('+7 days',
                      style:
                          AppTypography.caption.copyWith(color: lum.beam)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Mean of the last [window] entries (or all if fewer). Series is non-empty.
  double _trailingAverage(List<double> series, int window) {
    final start = series.length > window ? series.length - window : 0;
    final tail = series.sublist(start);
    return tail.fold<double>(0, (a, b) => a + b) / tail.length;
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: lum.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 7),
        Text('Actual', style: AppTypography.caption.copyWith(color: lum.g600)),
        const SizedBox(width: 16),
        SizedBox(
          width: 16,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: lum.beam, width: 2.5, style: BorderStyle.solid),
              ),
            ),
            child: const SizedBox(height: 3),
          ),
        ),
        const SizedBox(width: 7),
        Text('Projected',
            style: AppTypography.caption.copyWith(color: lum.g600)),
      ],
    );
  }
}
