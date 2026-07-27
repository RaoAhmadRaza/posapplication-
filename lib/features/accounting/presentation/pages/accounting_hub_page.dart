import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/widgets/module_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../widgets/acct_hub_grid.dart';

/// Accounting hub — the module's branch root. Grouped destination tiles over the
/// shared module chrome. Descriptions are static design copy; no fabricated
/// counts (the mock's "34 accounts" has no source on this page).
class AccountingHubPage extends StatelessWidget {
  const AccountingHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;

    List<AcctHubItem> items() => [
          AcctHubItem(
            icon: LucideIcons.listTree,
            label: 'Chart of accounts',
            description: 'Ledger accounts & balances',
            iconBackground: lum.accentSoft,
            iconForeground: lum.accent,
            onTap: () => context.push('/accounting/accounts'),
          ),
          AcctHubItem(
            icon: LucideIcons.notebookPen,
            label: 'Journal entries',
            description: 'Double-entry postings',
            iconBackground: lum.accentSoft,
            iconForeground: lum.accent,
            onTap: () => context.push('/accounting/journal'),
          ),
          AcctHubItem(
            icon: LucideIcons.receiptText,
            label: 'Manual vouchers',
            description: 'Payment · receipt · journal',
            iconBackground: lum.accentSoft,
            iconForeground: lum.accent,
            onTap: () => context.push('/accounting/vouchers'),
          ),
          AcctHubItem(
            icon: LucideIcons.wallet,
            label: 'Expenses',
            description: 'Day-to-day spending',
            iconBackground: lum.warningSoft,
            iconForeground: lum.warningText,
            onTap: () => context.push('/accounting/expenses'),
          ),
          AcctHubItem(
            icon: LucideIcons.landmark,
            label: 'Bank accounts',
            description: 'Bank & cash accounts',
            iconBackground: lum.accentSoft,
            iconForeground: lum.accent,
            onTap: () => context.push('/accounting/banks'),
          ),
          AcctHubItem(
            icon: LucideIcons.percent,
            label: 'Tax rules',
            description: 'GST & withholding',
            iconBackground: lum.transitSoft,
            iconForeground: lum.transitText,
            onTap: () => context.push('/accounting/tax-rules'),
          ),
          AcctHubItem(
            icon: LucideIcons.scale,
            label: 'Trial balance',
            description: 'As of a date',
            iconBackground: lum.successSoft,
            iconForeground: lum.successText,
            onTap: () => context.push('/accounting/reports/trial-balance'),
          ),
          AcctHubItem(
            icon: LucideIcons.trendingUp,
            label: 'Profit & loss',
            description: 'For a period',
            iconBackground: lum.successSoft,
            iconForeground: lum.successText,
            onTap: () => context.push('/accounting/reports/profit-loss'),
          ),
          AcctHubItem(
            icon: LucideIcons.layoutPanelLeft,
            label: 'Balance sheet',
            description: 'Financial position',
            iconBackground: lum.successSoft,
            iconForeground: lum.successText,
            onTap: () => context.push('/accounting/reports/balance-sheet'),
          ),
          AcctHubItem(
            icon: LucideIcons.bookOpen,
            label: 'Cash & bank book',
            description: 'Running balances',
            iconBackground: lum.successSoft,
            iconForeground: lum.successText,
            onTap: () => context.push('/accounting/reports/cash-bank-book'),
          ),
          AcctHubItem(
            icon: LucideIcons.calendarRange,
            label: 'Fiscal periods',
            description: 'Open · closed · locked',
            iconBackground: lum.surface2,
            iconForeground: lum.g600,
            onTap: () => context.push('/accounting/periods'),
          ),
          AcctHubItem(
            icon: LucideIcons.gitCompareArrows,
            label: 'Bank reconciliation',
            description: 'Match statements',
            iconBackground: lum.surface2,
            iconForeground: lum.g600,
            onTap: () => context.push('/accounting/banks'),
          ),
        ];

    return ModuleScaffold(
      title: 'Accounting',
      // Wider on desktop so the two-column grid fills the space instead of
      // stranding the cards in a narrow centred column.
      maxContentWidth: 1180,
      padding: EdgeInsets.zero,
      // Nav hides this module without accounting:read, but the route stays
      // reachable by deep link — gate the page too.
      child: PermissionGate(
        module: 'accounting',
        action: 'read',
        fallback: Center(
          child: Text(
            'You don’t have access to accounting.',
            style: AppTypography.subhead.copyWith(color: lum.g500),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
          child: AcctHubGrid(items: items()),
        ),
      ),
    );
  }
}
