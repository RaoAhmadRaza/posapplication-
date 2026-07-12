import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../domain/entities/account_ledger.dart';
import '../controllers/chart_of_accounts_controller.dart';

class AccountLedgerPage extends ConsumerWidget {
  const AccountLedgerPage({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountLedgerProvider(accountId));

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
        title: Text('Ledger', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding),
              child: AppInlineBanner(
                  message: 'Could not load ledger.',
                  type: BannerType.error),
            ),
          ),
          data: (ledger) => _LedgerView(ledger: ledger),
        ),
      ),
    );
  }
}

class _LedgerView extends StatelessWidget {
  const _LedgerView({required this.ledger});
  final AccountLedger ledger;

  @override
  Widget build(BuildContext context) {
    final entries = ledger.entries;
    return ListView(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
      children: [
        AppCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Opening Balance',
                  style: AppTypography.subhead
                      .copyWith(color: AppColors.textMuted)),
              Text(formatPkr(ledger.openingBalance),
                  style: AppTypography.headline),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxl),
            child: Center(
              child: Text('No transactions',
                  style: AppTypography.subhead
                      .copyWith(color: AppColors.textMuted)),
            ),
          )
        else
          for (final entry in entries) ...[
            _EntryRow(entry: entry),
            const SizedBox(height: AppSpacing.sm),
          ],
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});
  final AccountLedgerEntry entry;

  String _date(DateTime? d) {
    if (d == null) return '';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDebit = entry.debit > 0;
    final amount = isDebit ? entry.debit : entry.credit;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(entry.entryNumber ?? '—',
                    style: AppTypography.subhead
                        .copyWith(fontWeight: FontWeight.w600)),
              ),
              Text(_date(entry.date),
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMuted)),
            ],
          ),
          if (entry.description != null &&
              entry.description!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(entry.description!,
                style: AppTypography.footnote
                    .copyWith(color: AppColors.textMuted)),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${isDebit ? 'Debit' : 'Credit'}  ${formatPkr(amount)}',
                  style: AppTypography.footnote.copyWith(
                      color: isDebit
                          ? AppColors.success
                          : AppColors.destructive)),
              Text(formatPkr(entry.runningBalance),
                  style: AppTypography.subhead
                      .copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
