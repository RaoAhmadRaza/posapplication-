import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/widgets/module_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';

/// One report entry on the hub.
class _Row {
  const _Row(this.icon, this.title, this.desc, this.route, {this.external = false});
  final IconData icon;
  final String title;
  final String desc;
  final String route;

  /// True for rows that leave the module (open in Accounting) — shown with an
  /// up-right chevron instead of the in-module right chevron.
  final bool external;
}

class ReportsHubPage extends StatelessWidget {
  const ReportsHubPage({super.key});

  static const _sections = <(String, List<_Row>)>[
    (
      'Operations',
      [
        _Row(LucideIcons.boxes, 'Inventory', 'Stock value & reorder alerts',
            '/reports/inventory'),
        _Row(LucideIcons.trendingUp, 'Product performance',
            'Best sellers by revenue, profit, units', '/reports/products'),
        _Row(LucideIcons.activity, 'Trend analysis',
            'Revenue & profit over time', '/reports/trends'),
        _Row(LucideIcons.lineChart, 'Forecasting', '7-day sales projection',
            '/reports/forecast'),
        _Row(LucideIcons.sparkles, 'Smart insights', 'Suggested actions',
            '/reports/insights'),
      ],
    ),
    (
      'Receivables & payables',
      [
        _Row(LucideIcons.userRound, 'Customer aging',
            'Receivables by age bucket', '/reports/customers'),
        _Row(LucideIcons.truck, 'Supplier aging', 'Payables by age bucket',
            '/reports/suppliers'),
      ],
    ),
    (
      'Financial · opens in Accounting',
      [
        _Row(LucideIcons.scale, 'Trial balance', 'Debits vs credits, as of a date',
            '/accounting/reports/trial-balance', external: true),
        _Row(LucideIcons.fileText, 'Profit & loss', 'Revenue, expenses, net profit',
            '/accounting/reports/profit-loss', external: true),
        _Row(LucideIcons.book, 'Balance sheet', 'Assets vs liabilities and equity',
            '/accounting/reports/balance-sheet', external: true),
        _Row(LucideIcons.landmark, 'Cash & bank book',
            'Running balance for cash or a bank',
            '/accounting/reports/cash-bank-book', external: true),
      ],
    ),
    (
      'Scheduling',
      [
        _Row(LucideIcons.calendarClock, 'Scheduled reports',
            'Automated email delivery', '/reports/schedules'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return ModuleScaffold(
      title: 'Reports',
      child: PermissionGate(
        module: 'reports',
        action: 'read',
        fallback: Center(
          child: Text(
            'You don’t have access to reports.',
            style: AppTypography.subhead.copyWith(color: lum.g500),
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (title, rows) in _sections) ...[
                      _Section(title: title, rows: rows),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: lum.g500,
            ),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                _HubRow(row: rows[i], first: i == 0),
            ],
          ),
        ),
      ],
    );
  }
}

class _HubRow extends StatelessWidget {
  const _HubRow({required this.row, required this.first});

  final _Row row;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      button: true,
      label: row.title,
      child: InkWell(
        onTap: () => context.push(row.route),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            border: first
                ? null
                : Border(top: BorderSide(color: lum.hairline)),
          ),
          child: Row(
            children: [
              ClayContainer(
                variant: ClayVariant.soft,
                color: lum.accentSoft,
                borderRadius: 13,
                isDark: lum.isDark,
                width: 42,
                height: 42,
                child: Icon(row.icon, size: 20, color: lum.accent),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.title,
                      style: AppTypography.callout.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: lum.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      row.desc,
                      style: AppTypography.footnote.copyWith(color: lum.g500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                row.external ? LucideIcons.arrowUpRight : LucideIcons.chevronRight,
                size: 18,
                color: lum.g400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
