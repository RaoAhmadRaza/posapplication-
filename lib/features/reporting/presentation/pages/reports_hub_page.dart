import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/widgets/permission_gate.dart';

class ReportsHubPage extends StatelessWidget {
  const ReportsHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text('Reports', style: AppTypography.largeTitle),
      ),
      body: SafeArea(
        child: PermissionGate(
          module: 'reports',
          action: 'read',
          fallback: Center(
            child: Text('No access to reports.',
                style: AppTypography.subhead
                    .copyWith(color: AppColors.textMuted)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xl),
                _section('Financial'),
                _ReportRow(
                  icon: Icons.balance,
                  title: 'Trial Balance',
                  subtitle: 'Debits vs credits, as of a date',
                  onTap: () =>
                      context.push('/accounting/reports/trial-balance'),
                ),
                _ReportRow(
                  icon: Icons.trending_up,
                  title: 'Profit & Loss',
                  subtitle: 'Revenue, expenses, net profit',
                  onTap: () => context.push('/accounting/reports/profit-loss'),
                ),
                _ReportRow(
                  icon: Icons.account_balance,
                  title: 'Balance Sheet',
                  subtitle: 'Assets vs liabilities and equity',
                  onTap: () =>
                      context.push('/accounting/reports/balance-sheet'),
                ),
                _ReportRow(
                  icon: Icons.menu_book,
                  title: 'Cash / Bank Book',
                  subtitle: 'Running balance for cash or a bank',
                  onTap: () =>
                      context.push('/accounting/reports/cash-bank-book'),
                ),
                const SizedBox(height: AppSpacing.xl),
                _section('Operations'),
                _ReportRow(
                  icon: Icons.inventory_2,
                  title: 'Inventory',
                  subtitle: 'Stock value, low stock, value by category',
                  onTap: () => context.push('/reports/inventory'),
                ),
                _ReportRow(
                  icon: Icons.emoji_events,
                  title: 'Product Performance',
                  subtitle: 'Top sellers by revenue, profit, units',
                  onTap: () => context.push('/reports/products'),
                ),
                _ReportRow(
                  icon: Icons.show_chart,
                  title: 'Trends',
                  subtitle: 'Revenue and profit over a date range',
                  onTap: () => context.push('/reports/trends'),
                ),
                _ReportRow(
                  icon: Icons.auto_graph,
                  title: 'Forecasting',
                  subtitle: 'Rules-based revenue projection (estimate)',
                  onTap: () => context.push('/reports/forecast'),
                ),
                _ReportRow(
                  icon: Icons.lightbulb_outline,
                  title: 'Smart Insights',
                  subtitle: 'Reorder recommendations to accept or dismiss',
                  onTap: () => context.push('/reports/insights'),
                ),
                const SizedBox(height: AppSpacing.xl),
                _section('Receivables & Payables'),
                _ReportRow(
                  icon: Icons.people,
                  title: 'Customer Aging',
                  subtitle: 'Outstanding balances by age bucket',
                  onTap: () => context.push('/reports/customers'),
                ),
                _ReportRow(
                  icon: Icons.local_shipping,
                  title: 'Supplier Aging',
                  subtitle: 'Payables by age bucket',
                  onTap: () => context.push('/reports/suppliers'),
                ),
                const SizedBox(height: AppSpacing.xl),
                _section('Scheduling'),
                _ReportRow(
                  icon: Icons.schedule,
                  title: 'Scheduled Reports',
                  subtitle: 'Recurring report deliveries (email via M11)',
                  onTap: () => context.push('/reports/schedules'),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(title,
            style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
      );
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.sm),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.accent, size: 20),
        ),
        title: Text(title,
            style:
                AppTypography.headline.copyWith(color: AppColors.textPrimary)),
        subtitle: Text(
          subtitle,
          style: AppTypography.footnote.copyWith(color: AppColors.textHint),
        ),
        trailing:
            const Icon(Icons.chevron_right, color: AppColors.separator),
        onTap: onTap,
      ),
    );
  }
}
