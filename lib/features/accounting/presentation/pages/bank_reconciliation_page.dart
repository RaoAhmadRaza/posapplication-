import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/bank_account.dart';
import '../../domain/entities/bank_reconciliation.dart';
import '../../domain/entities/reconciliation_result.dart';
import '../controllers/bank_accounts_controller.dart';
import '../controllers/bank_reconciliation_controller.dart';
import '../controllers/chart_of_accounts_controller.dart';
import '../widgets/acct_account_picker.dart';
import '../widgets/acct_date_field.dart';
import '../widgets/accounting_ui.dart';

class BankReconciliationPage extends ConsumerStatefulWidget {
  const BankReconciliationPage({super.key, required this.bankAccountId});

  final String bankAccountId;

  @override
  ConsumerState<BankReconciliationPage> createState() =>
      _BankReconciliationPageState();
}

class _BankReconciliationPageState
    extends ConsumerState<BankReconciliationPage> {
  final _statementBalance = TextEditingController();
  final _reconciledBalance = TextEditingController();
  DateTime _statementDate = DateTime.now();
  ReconciliationResult? _result;
  Account? _adjustmentAccount;
  bool _busy = false;

  Future<void> _pickAdjustmentAccount() async {
    final accounts = ref.read(chartOfAccountsProvider).value ?? const [];
    // Exclude the bank's own chart account: an adjustment posted against it would
    // cancel itself out (both legs on the same account = no-op).
    final bankChartId = ref
        .read(bankAccountsProvider)
        .value
        ?.where((a) => a.id == widget.bankAccountId)
        .cast<BankAccount?>()
        .firstOrNull
        ?.chartAccountId;
    final options =
        accounts.where((a) => a.id != bankChartId).toList(growable: false);
    final picked = await showAccountPicker(context, options,
        title: 'Adjustment account');
    if (picked != null) setState(() => _adjustmentAccount = picked);
  }

  @override
  void dispose() {
    _statementBalance.dispose();
    _reconciledBalance.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final balance = double.tryParse(_statementBalance.text.trim());
    if (balance == null) {
      showAppToast(context, 'Enter a valid statement balance.',
          type: BannerType.error);
      return;
    }
    setState(() => _busy = true);
    final (result, failure) = await ref
        .read(bankReconciliationControllerProvider.notifier)
        .createReconciliation(
          bankAccountId: widget.bankAccountId,
          statementDate: _statementDate,
          statementBalance: balance,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result;
    });
    if (failure != null) {
      showAppToast(context, failure.message, type: BannerType.error);
    }
  }

  Future<void> _complete() async {
    final result = _result;
    if (result == null) return;
    final balance = double.tryParse(_reconciledBalance.text.trim());
    if (balance == null) {
      showAppToast(context, 'Enter a valid reconciled balance.',
          type: BannerType.error);
      return;
    }
    // A difference from the books must be booked somewhere — the RPC posts a
    // balancing journal against the account the user names (the real cause).
    final needsAdjustment = (balance - result.ledgerBalance).abs() >= 0.005;
    if (needsAdjustment && _adjustmentAccount == null) {
      showAppToast(context, 'Choose an account for the difference.',
          type: BannerType.error);
      return;
    }
    setState(() => _busy = true);
    final failure = await ref
        .read(bankReconciliationControllerProvider.notifier)
        .completeReconciliation(
          bankAccountId: widget.bankAccountId,
          reconciliationId: result.reconciliationId,
          reconciledBalance: balance,
          adjustmentAccountCode: _adjustmentAccount?.code,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure != null) {
      showAppToast(context, failure.message, type: BannerType.error);
      return;
    }
    setState(() {
      _result = null;
      _adjustmentAccount = null;
      _statementBalance.clear();
      _reconciledBalance.clear();
    });
    showAppToast(context, 'Reconciliation completed',
        type: BannerType.success);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(bankAccountsProvider);
    final priors = ref.watch(bankReconciliationsProvider(widget.bankAccountId));
    final name = accounts.value
            ?.where((a) => a.id == widget.bankAccountId)
            .cast<BankAccount?>()
            .firstOrNull
            ?.accountName ??
        'Bank Account';

    return AppDetailScaffold(
      eyebrow: 'Accounting',
      title: 'Reconcile',
      description: name,
      maxContentWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NewReconciliationCard(
            statementDate: _statementDate,
            statementBalance: _statementBalance,
            busy: _busy,
            onPickDate: (v) {
              if (v != null) setState(() => _statementDate = v);
            },
            onCreate: _busy ? null : _create,
          ),
          if (_result != null) ...[
            const SizedBox(height: 20),
            _ResultBlock(result: _result!),
            const SizedBox(height: 20),
            _RecordCard(
              reconciledBalance: _reconciledBalance,
              busy: _busy,
              hasDifference: _result!.difference != 0,
              adjustmentAccount: _adjustmentAccount,
              onPickAccount: _pickAdjustmentAccount,
              onComplete: _busy ? null : _complete,
            ),
          ],
          const SizedBox(height: 20),
          _PriorsCard(priors: priors),
        ],
      ),
    );
  }
}

class _NewReconciliationCard extends StatelessWidget {
  const _NewReconciliationCard({
    required this.statementDate,
    required this.statementBalance,
    required this.busy,
    required this.onPickDate,
    required this.onCreate,
  });

  final DateTime statementDate;
  final TextEditingController statementBalance;
  final bool busy;
  final ValueChanged<DateTime?> onPickDate;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AcctSectionLabel('New reconciliation'),
          const SizedBox(height: 14),
          _FieldsGrid(
            children: [
              _Labeled(
                'Statement date',
                AcctDateField(
                  value: statementDate,
                  onChanged: onPickDate,
                ),
              ),
              AppTextField(
                controller: statementBalance,
                label: 'Statement balance',
                prefixIcon: LucideIcons.banknote,
                hint: '0',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PermissionGate(
            module: 'accounting',
            action: 'create',
            child: AppButton(
              label: 'Start reconciliation',
              variant: AppButtonVariant.tinted,
              icon: LucideIcons.play,
              fullWidth: true,
              loading: busy,
              onPressed: onCreate,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultBlock extends StatelessWidget {
  const _ResultBlock({required this.result});
  final ReconciliationResult result;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final matched = result.difference == 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lum.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: lum.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ValueRow(label: 'Ledger balance', value: result.ledgerBalance),
          const SizedBox(height: 12),
          _ValueRow(label: 'Statement balance', value: result.statementBalance),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: matched ? lum.successSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: matched
                ? Row(
                    children: [
                      Icon(LucideIcons.checkCheck,
                          size: 17, color: lum.successText),
                      const SizedBox(width: 8),
                      Text(
                        'Matched · ${formatPkr(0)}',
                        style: AppTypography.subhead.copyWith(
                          color: lum.successText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Difference',
                          style: AppTypography.subhead
                              .copyWith(color: lum.textSecondary),
                        ),
                      ),
                      AppMoneyText(result.difference,
                          size: 16, color: lum.danger),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.subhead.copyWith(color: lum.textSecondary),
          ),
        ),
        AppMoneyText(value, size: 16),
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.reconciledBalance,
    required this.busy,
    required this.hasDifference,
    required this.adjustmentAccount,
    required this.onPickAccount,
    required this.onComplete,
  });

  final TextEditingController reconciledBalance;
  final bool busy;
  final bool hasDifference;
  final Account? adjustmentAccount;
  final VoidCallback onPickAccount;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AcctSectionLabel('Record reconciled balance'),
          const SizedBox(height: 14),
          AppTextField(
            controller: reconciledBalance,
            label: 'Reconciled balance',
            prefixIcon: LucideIcons.banknote,
            hint: '0',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          if (hasDifference) ...[
            const SizedBox(height: 14),
            const AcctSectionLabel('Adjustment account'),
            const SizedBox(height: 7),
            Text(
              'The difference posts a balancing journal to this account.',
              style: AppTypography.footnote.copyWith(color: lum.g500),
            ),
            const SizedBox(height: 8),
            Semantics(
              button: true,
              label: adjustmentAccount == null
                  ? 'Choose adjustment account'
                  : '${adjustmentAccount!.code} ${adjustmentAccount!.name}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onPickAccount,
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    color: lum.surface2,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: lum.hairline),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.listTree, size: 17, color: lum.g500),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          adjustmentAccount == null
                              ? 'Choose account'
                              : '${adjustmentAccount!.code} · ${adjustmentAccount!.name}',
                          style: AppTypography.subhead.copyWith(
                            color: adjustmentAccount == null
                                ? lum.textTertiary
                                : lum.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(LucideIcons.chevronDown, size: 15, color: lum.g400),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          PermissionGate(
            module: 'accounting',
            action: 'approve',
            child: AppButton(
              label: 'Complete',
              icon: LucideIcons.check,
              fullWidth: true,
              loading: busy,
              onPressed: onComplete,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorsCard extends StatelessWidget {
  const _PriorsCard({required this.priors});

  final AsyncValue<List<BankReconciliation>> priors;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Prior reconciliations', style: AppTypography.headline),
          const SizedBox(height: 14),
          priors.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => AppInlineBanner(
              message: 'Could not load reconciliations.',
              type: BannerType.error,
            ),
            data: (items) => items.isEmpty
                ? Text(
                    'No reconciliations yet',
                    style: AppTypography.subhead
                        .copyWith(color: lum.textTertiary),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0)
                          Divider(height: 20, color: lum.hairline),
                        _PriorRow(reconciliation: items[i]),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PriorRow extends StatelessWidget {
  const _PriorRow({required this.reconciliation});
  final BankReconciliation reconciliation;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final completed = reconciliation.status.toUpperCase() == 'COMPLETED';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            acctFormatDate(reconciliation.statementDate),
            style: AppTypography.subhead.copyWith(
              color: lum.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AppMoneyText(reconciliation.reconciledBalance, size: 15),
            const SizedBox(height: 7),
            AppPill(
              label: acctRefLabel(reconciliation.status),
              tone: completed ? AppPillTone.success : AppPillTone.neutral,
            ),
          ],
        ),
      ],
    );
  }
}

/// Two columns on a wide card, one on a narrow one — each cell keeps its
/// control's natural height.
class _FieldsGrid extends StatelessWidget {
  const _FieldsGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const gap = 16.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCol = constraints.maxWidth >= 460;
        final width =
            twoCol ? (constraints.maxWidth - gap) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

/// A section label stacked above a control that carries no label of its own.
class _Labeled extends StatelessWidget {
  const _Labeled(this.label, this.child);

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AcctSectionLabel(label),
        const SizedBox(height: 7),
        child,
      ],
    );
  }
}
