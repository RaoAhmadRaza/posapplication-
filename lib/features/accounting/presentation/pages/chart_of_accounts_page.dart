import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/account.dart';
import '../controllers/chart_of_accounts_controller.dart';

const _typeLabels = <AccountType, String>{
  AccountType.asset: 'Assets',
  AccountType.liability: 'Liabilities',
  AccountType.equity: 'Equity',
  AccountType.revenue: 'Revenue',
  AccountType.expense: 'Expenses',
};

class ChartOfAccountsPage extends ConsumerStatefulWidget {
  const ChartOfAccountsPage({super.key});

  @override
  ConsumerState<ChartOfAccountsPage> createState() =>
      _ChartOfAccountsPageState();
}

class _ChartOfAccountsPageState extends ConsumerState<ChartOfAccountsPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Account a) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return a.code.toLowerCase().contains(q) ||
        a.name.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chartOfAccountsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Chart of Accounts', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
                  AppSpacing.md, AppSpacing.screenPadding, AppSpacing.sm),
              child: AppTextField(
                controller: _search,
                label: 'Search',
                prefixIcon: Icons.search,
                hint: 'Code or name',
                onSubmitted: (v) => setState(() => _query = v.trim()),
              ),
            ),
            Expanded(
              child: state.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorState(
                  onRetry: () =>
                      ref.read(chartOfAccountsProvider.notifier).refresh(),
                ),
                data: (accounts) {
                  final visible = accounts.where(_matches).toList();
                  return ListView(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                    children: [
                      for (final type in AccountType.values)
                        _TypeSection(
                          type: type,
                          all: accounts,
                          visible: visible,
                          expanded: _query.isNotEmpty,
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeSection extends StatelessWidget {
  const _TypeSection({
    required this.type,
    required this.all,
    required this.visible,
    required this.expanded,
  });

  final AccountType type;
  final List<Account> all;
  final List<Account> visible;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final roots = visible
        .where((a) => a.type == type && a.parentId == null)
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    // Orphans: matched children whose parent is not in the same type/visible.
    final rootIds = roots.map((a) => a.id).toSet();
    final orphans = visible
        .where((a) =>
            a.type == type &&
            a.parentId != null &&
            !rootIds.contains(a.parentId))
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    final topLevel = [...roots, ...orphans];
    if (topLevel.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: expanded,
          tilePadding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          title: Text(_typeLabels[type] ?? type.name,
              style: AppTypography.headline),
          childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
          children: [
            for (final account in topLevel) ...[
              _AccountRow(account: account, depth: 0),
              for (final child in all
                  .where((c) => c.parentId == account.id)
                  .toList()
                ..sort((a, b) => a.code.compareTo(b.code)))
                _AccountRow(account: child, depth: 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.depth});

  final Account account;
  final int depth;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          context.push('/accounting/accounts/${account.id}/ledger'),
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.base + depth * AppSpacing.lg,
          right: AppSpacing.md,
          top: AppSpacing.sm,
          bottom: AppSpacing.sm,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Text(account.code,
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.textMuted)),
            ),
            Expanded(
              child: Text(account.name,
                  style: AppTypography.subhead,
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(formatPkr(account.currentBalance),
                style: AppTypography.footnote.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppInlineBanner(
                message: 'Could not load accounts.',
                type: BannerType.error),
            const SizedBox(height: AppSpacing.md),
            AppButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
