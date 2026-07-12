import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/bank_account.dart';
import '../controllers/bank_accounts_controller.dart';

class BankAccountsPage extends ConsumerWidget {
  const BankAccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bankAccountsProvider);

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
        title: Text('Bank Accounts', style: AppTypography.headline),
      ),
      floatingActionButton: PermissionGate(
        module: 'accounting',
        action: 'create',
        child: FloatingActionButton(
          backgroundColor: AppColors.accent,
          onPressed: () => context.push('/accounting/banks/create'),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(
            onRetry: () => ref.read(bankAccountsProvider.notifier).refresh(),
          ),
          data: (accounts) => accounts.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPadding,
                      vertical: AppSpacing.md),
                  itemCount: accounts.length,
                  itemBuilder: (_, i) => Padding(
                    padding: EdgeInsets.only(
                        bottom:
                            i < accounts.length - 1 ? AppSpacing.md : 0),
                    child: _BankCard(account: accounts[i]),
                  ),
                ),
        ),
      ),
    );
  }
}

class _BankCard extends StatelessWidget {
  const _BankCard({required this.account});
  final BankAccount account;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: InkWell(
        onTap: () => context.push('/accounting/banks/${account.id}/edit'),
        borderRadius: BorderRadius.circular(AppSpacing.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(account.accountName,
                        style: AppTypography.headline),
                  ),
                  Text(formatPkr(account.currentBalance),
                      style: AppTypography.headline),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(account.bankName ?? '—',
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.textMuted)),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => context
                      .push('/accounting/banks/${account.id}/reconcile'),
                  icon: const Icon(Icons.rule, size: 16),
                  label: const Text('Reconcile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_balance,
              size: 48, color: AppColors.textHint),
          const SizedBox(height: AppSpacing.md),
          Text('No bank accounts',
              style:
                  AppTypography.subhead.copyWith(color: AppColors.textMuted)),
        ],
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
                message: 'Could not load bank accounts.',
                type: BannerType.error),
            const SizedBox(height: AppSpacing.md),
            AppButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
