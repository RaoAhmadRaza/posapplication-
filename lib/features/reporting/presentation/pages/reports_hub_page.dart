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

/// One report card on the hub.
class _Row {
  const _Row(this.icon, this.title, this.desc, this.route,
      {this.external = false, this.isNew = false});
  final IconData icon;
  final String title;
  final String desc;
  final String route;

  /// True for cards that leave the module (open in Accounting) — marked with a
  /// small up-right arrow in the card's top corner.
  final bool external;

  /// Draws an accent border + "New" pill. One card at most, by design.
  final bool isNew;
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
            '/reports/insights', isNew: true),
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
                constraints: const BoxConstraints(maxWidth: 960),
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
        LayoutBuilder(
          builder: (context, c) => GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: c.maxWidth >= 700 ? 3 : (c.maxWidth >= 460 ? 2 : 1),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              // Fixed extent rather than an aspect ratio so a card is the same
              // height whatever the column width (~square at 3-up desktop).
              mainAxisExtent: 152,
            ),
            itemBuilder: (context, i) => _HubCard(row: rows[i]),
          ),
        ),
      ],
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({required this.row});

  final _Row row;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final Widget card = AppCard(
      padding: const EdgeInsets.all(16),
      onTap: () => context.push(row.route),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // Icon pinned top, text pinned bottom, so cards keep the same visual
        // weight however long the subtitle runs.
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const Spacer(),
              if (row.isNew)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: lum.accentSoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'New',
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: lum.accent,
                    ),
                  ),
                )
              else if (row.external)
                Icon(LucideIcons.arrowUpRight, size: 16, color: lum.g400),
            ],
          ),
          Column(
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
              const SizedBox(height: 3),
              Text(
                row.desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.footnote.copyWith(color: lum.g500),
              ),
            ],
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: row.title,
      child: row.isNew
          ? DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: lum.accent.withValues(alpha: 0.45),
                ),
              ),
              child: card,
            )
          : card,
    );
  }
}
