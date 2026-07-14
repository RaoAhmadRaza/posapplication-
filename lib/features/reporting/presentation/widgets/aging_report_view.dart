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

/// Shared aging-report UI. Both customer and supplier pages wrap this,
/// passing the matching provider + labels.
class AgingReportView extends ConsumerWidget {
  const AgingReportView({
    super.key,
    required this.provider,
    required this.title,
    required this.entityLabel,
  });

  final FutureProvider<List<AgingRow>> provider;
  final String title;
  final String entityLabel;

  static const _bucketNames = ['Current', '1-30', '31-60', '61-90', '90+'];
  static const _bucketColors = [
    AppColors.success,
    AppColors.accent,
    AppColors.warning,
    Color(0xFFFF6B30),
    AppColors.destructive,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text(title, style: AppTypography.largeTitle),
      ),
      body: PermissionGate(
        module: 'reports',
        action: 'read',
        fallback: _muted('No access to reports.'),
        child: _buildBody(ref),
      ),
    );
  }

  Widget _buildBody(WidgetRef ref) {
    final state = ref.watch(provider);
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Padding(
        padding: EdgeInsets.all(AppSpacing.screenPadding),
        child: AppInlineBanner(
          message: 'Could not load report.',
          type: BannerType.error,
        ),
      ),
      data: (rows) {
        if (rows.isEmpty) return _muted('Nothing to show.');
        return _buildContent(rows);
      },
    );
  }

  Widget _buildContent(List<AgingRow> rows) {
    final total = rows.fold<double>(0, (sum, r) => sum + r.totalBalance);
    final buckets = _sumBuckets(rows);
    final sorted = [...rows]..sort((a, b) => b.totalBalance.compareTo(a.totalBalance));

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      children: [
        const SizedBox(height: AppSpacing.xs),
        _headlineCard(total),
        const SizedBox(height: AppSpacing.xl),
        _bucketsCard(buckets),
        const SizedBox(height: AppSpacing.xxl),
        Text('Top Balances', style: AppTypography.title2),
        const SizedBox(height: AppSpacing.md),
        ...sorted.map((r) => _BalanceRow(row: r)),
        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }

  List<double> _sumBuckets(List<AgingRow> rows) {
    var current = 0.0, b1 = 0.0, b31 = 0.0, b61 = 0.0, b90 = 0.0;
    for (final r in rows) {
      current += r.current;
      b1 += r.b1to30;
      b31 += r.b31to60;
      b61 += r.b61to90;
      b90 += r.b90plus;
    }
    return [current, b1, b31, b61, b90];
  }

  Widget _headlineCard(double total) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Outstanding',
            style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            formatPkr(total),
            style: AppTypography.title1.copyWith(color: AppColors.accent),
          ),
        ],
      ),
    );
  }

  Widget _bucketsCard(List<double> buckets) {
    final maxY = buckets.isEmpty
        ? 100.0
        : buckets.reduce((a, b) => a > b ? a : b) * 1.2;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Aging Buckets', style: AppTypography.headline),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 200,
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
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= _bucketNames.length) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _bucketNames[idx],
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
                  horizontalInterval:
                      maxY > 0 ? (maxY / 4).ceilToDouble() : 25,
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(buckets.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: buckets[i],
                        color: _bucketColors[i],
                        width: 22,
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

  Widget _muted(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.subhead.copyWith(color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.row});
  final AgingRow row;

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
                Text(row.name, style: AppTypography.headline),
                const SizedBox(height: 2),
                Text(
                  'Overdue up to ${row.maxDaysOverdue}d',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            formatPkr(row.totalBalance),
            style: AppTypography.headline
                .copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
