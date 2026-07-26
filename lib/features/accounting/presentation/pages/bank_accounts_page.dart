import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/bank_account.dart';
import '../controllers/bank_accounts_controller.dart';
import '../widgets/accounting_ui.dart';

class BankAccountsPage extends ConsumerWidget {
  const BankAccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bankAccountsProvider);

    return AppDetailScaffold(
      eyebrow: 'Accounting',
      title: 'Bank accounts',
      actions: [
        PermissionGate(
          module: 'accounting',
          action: 'create',
          child: AppButton(
            label: 'New account',
            icon: LucideIcons.plus,
            size: AppButtonSize.sm,
            onPressed: () => context.push('/accounting/banks/create'),
          ),
        ),
      ],
      child: state.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.only(top: 30),
          child: AppErrorState(
            title: 'Unable to load bank accounts',
            body: 'Check your connection and try again.',
            onRetry: () => ref.read(bankAccountsProvider.notifier).refresh(),
          ),
        ),
        data: (accounts) => accounts.isEmpty
            ? const Padding(
                padding: EdgeInsets.only(top: 20),
                child: AppEmptyState(
                  icon: LucideIcons.landmark,
                  title: 'No bank accounts yet',
                  body: 'Add a bank account to start reconciling.',
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final a in accounts) ...[
                    _BankCard(account: a),
                    const SizedBox(height: 12),
                  ],
                ],
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
    final lum = context.lum;
    final sub = [account.bankName, account.accountNumber]
        .where((s) => s != null && s.isNotEmpty)
        .join(' · ');

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AcctIconTile(
                icon: LucideIcons.landmark,
                background: lum.accentSoft,
                foreground: lum.accent,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      account.accountName,
                      style: AppTypography.headline
                          .copyWith(fontSize: 15, color: lum.textPrimary),
                    ),
                    if (sub.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: AppTypography.subhead
                            .copyWith(fontSize: 12.5, color: lum.g500),
                      ),
                    ],
                  ],
                ),
              ),
              if (account.isActive) ...[
                const SizedBox(width: 10),
                const AppPill(label: 'Active', tone: AppPillTone.success),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: lum.hairline),
                bottom: BorderSide(color: lum.hairline),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Balance',
                  style: AppTypography.subhead
                      .copyWith(fontSize: 13, color: lum.g500),
                ),
                AppMoneyText(account.currentBalance, size: 17),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              AppButton(
                label: 'Edit',
                variant: AppButtonVariant.tinted,
                size: AppButtonSize.sm,
                icon: LucideIcons.pencil,
                onPressed: () =>
                    context.push('/accounting/banks/${account.id}/edit'),
              ),
              const SizedBox(width: 10),
              AppButton(
                label: 'Reconcile',
                variant: AppButtonVariant.plain,
                size: AppButtonSize.sm,
                icon: LucideIcons.gitCompareArrows,
                onPressed: () =>
                    context.push('/accounting/banks/${account.id}/reconcile'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
