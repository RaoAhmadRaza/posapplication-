import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/reporting.dart';
import './report_export_button.dart';
import './reporting_bar_chart.dart';
import './reporting_stat_card.dart';
import './reporting_ui.dart';

/// Shared aging-report UI. Both customer and supplier pages wrap this, passing
/// the matching provider + labels.
class AgingReportView extends ConsumerWidget {
  const AgingReportView({
    super.key,
    required this.provider,
    required this.title,
    required this.description,
    required this.entityLabel,
  });

  final FutureProvider<List<AgingRow>> provider;
  final String title;
  final String description;
  final String entityLabel;

  static const _bucketNames = ['Current', '1–30', '31–60', '61–90', '90+'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final async = ref.watch(provider);
    return AppDetailScaffold(
      eyebrow: 'Reports',
      title: title,
      description: description,
      actions: [
        ReportExportButton(
          title: '$entityLabel Aging',
          headers: [
            entityLabel, 'Total', 'Current', '1-30', '31-60', '61-90', '90+',
            'Max Days',
          ],
          rowsBuilder: () {
            final rows = ref.read(provider).value ?? [];
            return rows
                .map((r) => [
                      r.name,
                      r.totalBalance.toStringAsFixed(2),
                      r.current.toStringAsFixed(2),
                      r.b1to30.toStringAsFixed(2),
                      r.b31to60.toStringAsFixed(2),
                      r.b61to90.toStringAsFixed(2),
                      r.b90plus.toStringAsFixed(2),
                      r.maxDaysOverdue.toString(),
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
            title: 'Couldn’t load the report',
            body: 'We couldn’t reach the server. Please try again.',
          ),
          data: (rows) => rows.isEmpty
              ? AppEmptyState(
                  icon: LucideIcons.banknote,
                  title: 'Nothing outstanding',
                  body: 'Balances by age will appear here when there are any.',
                )
              : _content(context, rows),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, List<AgingRow> rows) {
    final lum = context.lum;
    final total = rows.fold<double>(0, (s, r) => s + r.totalBalance);
    final over90 = rows.fold<double>(0, (s, r) => s + r.b90plus);
    final buckets = _sumBuckets(rows);
    final muted = Color.lerp(lum.accent, lum.surface, 0.5)!;
    final colors = [lum.accent, muted, lum.warning, lum.beam, lum.danger];
    final sorted = [...rows]
      ..sort((a, b) => b.totalBalance.compareTo(a.totalBalance));

    final bars = [
      for (var i = 0; i < buckets.length; i++)
        ReportingBar(
          label: _bucketNames[i],
          value: buckets[i],
          valueLabel: abbreviateNum(buckets[i]),
          color: colors[i],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReportingStatGrid(
          minTileWidth: 190,
          cards: [
            ReportingStatCard(
              label: 'Total outstanding',
              icon: LucideIcons.banknote,
              iconColor: lum.accent,
              value: AppMoneyText(total, size: 25),
            ),
            ReportingStatCard(
              label: 'Overdue · 90+ days',
              icon: LucideIcons.clock,
              iconColor: lum.danger,
              value: AppMoneyText(over90, size: 25, color: lum.dangerText),
            ),
            ReportingStatCard(
              label: '${entityLabel}s',
              icon: LucideIcons.users,
              value: ReportingStatValue('${rows.length}'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppSectionCard(
          eyebrow: 'Aging buckets',
          child: ReportingBarChart(bars: bars, height: 200),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppSectionCard(
          eyebrow: 'Top balances',
          padded: false,
          child: Column(
            children: [for (final r in sorted) _BalanceRow(row: r)],
          ),
        ),
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
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.row});
  final AgingRow row;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: lum.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  style: AppTypography.body.copyWith(color: lum.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'oldest ${row.maxDaysOverdue} days',
                  style: AppTypography.caption.copyWith(color: lum.g500),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          agingPill(row.maxDaysOverdue),
          const SizedBox(width: AppSpacing.md),
          AppMoneyText(row.totalBalance, size: 15),
        ],
      ),
    );
  }
}
