import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';

class AccountingHubPage extends StatelessWidget {
  const AccountingHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text('Accounting', style: AppTypography.largeTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),
              _HubRow(
                icon: Icons.account_tree,
                title: 'Chart of Accounts',
                subtitle: 'Ledger accounts and balances',
                onTap: () => context.push('/accounting/accounts'),
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.menu_book,
                title: 'Journal',
                subtitle: 'Posted journal entries',
                onTap: () => context.push('/accounting/journal'),
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.receipt,
                title: 'Vouchers',
                subtitle: 'Payment, receipt, contra, journal',
                onTap: () => context.push('/accounting/vouchers'),
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.money_off,
                title: 'Expenses',
                subtitle: 'Record and track expenses',
                onTap: () => context.push('/accounting/expenses'),
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.account_balance,
                title: 'Bank Accounts',
                subtitle: 'Bank and cash accounts',
                onTap: () => context.push('/accounting/banks'),
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.percent,
                title: 'Tax Rules',
                subtitle: 'Tax rates and defaults',
                onTap: () => context.push('/accounting/tax-rules'),
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.balance,
                title: 'Trial Balance',
                subtitle: 'Debits vs credits, as of a date',
                onTap: () => context.push('/accounting/reports/trial-balance'),
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.trending_up,
                title: 'Profit & Loss',
                subtitle: 'Revenue, expenses, net profit',
                onTap: () => context.push('/accounting/reports/profit-loss'),
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.account_balance,
                title: 'Balance Sheet',
                subtitle: 'Assets vs liabilities and equity',
                onTap: () => context.push('/accounting/reports/balance-sheet'),
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.menu_book,
                title: 'Cash / Bank Book',
                subtitle: 'Running balance for cash or a bank',
                onTap: () =>
                    context.push('/accounting/reports/cash-bank-book'),
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.event_available,
                title: 'Fiscal Periods',
                subtitle: 'Close or reopen accounting periods',
                onTap: () => context.push('/accounting/periods'),
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.rule,
                title: 'Bank Reconciliation',
                subtitle: 'Reconcile a bank statement to the books',
                onTap: () => context.push('/accounting/banks'),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubRow extends StatelessWidget {
  const _HubRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        subtitle: Text(subtitle,
            style: AppTypography.footnote.copyWith(color: AppColors.textHint)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.separator),
        onTap: onTap,
      ),
    );
  }
}
