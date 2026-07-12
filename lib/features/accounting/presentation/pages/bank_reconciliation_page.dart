import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/bank_account.dart';
import '../../domain/entities/bank_reconciliation.dart';
import '../../domain/entities/reconciliation_result.dart';
import '../controllers/bank_accounts_controller.dart';
import '../controllers/bank_reconciliation_controller.dart';

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
  bool _busy = false;

  @override
  void dispose() {
    _statementBalance.dispose();
    _reconciledBalance.dispose();
    super.dispose();
  }

  String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _statementDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _statementDate = picked);
  }

  Future<void> _create() async {
    final balance = double.tryParse(_statementBalance.text.trim());
    if (balance == null) {
      _snack('Enter a valid statement balance.');
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
    if (failure != null) _snack(failure.message);
  }

  Future<void> _complete() async {
    final result = _result;
    if (result == null) return;
    final balance = double.tryParse(_reconciledBalance.text.trim());
    if (balance == null) {
      _snack('Enter a valid reconciled balance.');
      return;
    }
    setState(() => _busy = true);
    final failure = await ref
        .read(bankReconciliationControllerProvider.notifier)
        .completeReconciliation(
          bankAccountId: widget.bankAccountId,
          reconciliationId: result.reconciliationId,
          reconciledBalance: balance,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure != null) {
      _snack(failure.message);
      return;
    }
    setState(() {
      _result = null;
      _statementBalance.clear();
      _reconciledBalance.clear();
    });
    _snack('Reconciliation completed');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
        title: Text('Reconcile', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
          children: [
            Text(name, style: AppTypography.title2),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Manual balance reconciliation — snapshot statement vs books, '
              'not line-by-line matching.',
              style:
                  AppTypography.footnote.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            _NewReconciliationForm(
              statementDateLabel: _day(_statementDate),
              statementBalance: _statementBalance,
              busy: _busy,
              onPickDate: _pickDate,
              onCreate: _create,
            ),
            if (_result != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _ResultCard(result: _result!),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _reconciledBalance,
                label: 'Record reconciled balance',
                prefixIcon: Icons.check_circle_outline,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: AppSpacing.md),
              PermissionGate(
                module: 'accounting',
                action: 'approve',
                child: AppButton(
                  label: 'Complete',
                  fullWidth: true,
                  loading: _busy,
                  onPressed: _busy ? null : _complete,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Text('Prior reconciliations', style: AppTypography.headline),
            const SizedBox(height: AppSpacing.md),
            priors.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => AppInlineBanner(
                  message: 'Could not load reconciliations.',
                  type: BannerType.error),
              data: (items) => items.isEmpty
                  ? Text('None yet',
                      style: AppTypography.subhead
                          .copyWith(color: AppColors.textMuted))
                  : Column(
                      children: [
                        for (final r in items) ...[
                          _PriorTile(reconciliation: r),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _NewReconciliationForm extends StatelessWidget {
  const _NewReconciliationForm({
    required this.statementDateLabel,
    required this.statementBalance,
    required this.busy,
    required this.onPickDate,
    required this.onCreate,
  });

  final String statementDateLabel;
  final TextEditingController statementBalance;
  final bool busy;
  final VoidCallback onPickDate;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New reconciliation', style: AppTypography.headline),
          const SizedBox(height: AppSpacing.md),
          Text('Statement date', style: AppTypography.fieldLabel),
          const SizedBox(height: AppSpacing.xs),
          InkWell(
            onTap: onPickDate,
            borderRadius: BorderRadius.circular(AppRadius.field),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.fieldFill,
                borderRadius: BorderRadius.circular(AppRadius.field),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: AppColors.textMuted, size: 20),
                  const SizedBox(width: 10),
                  Text(statementDateLabel, style: AppTypography.fieldText),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.fieldGap),
          AppTextField(
            controller: statementBalance,
            label: 'Statement balance',
            prefixIcon: Icons.account_balance,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: AppSpacing.md),
          PermissionGate(
            module: 'accounting',
            action: 'create',
            child: AppButton(
              label: 'Start reconciliation',
              fullWidth: true,
              loading: busy,
              onPressed: busy ? null : onCreate,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final ReconciliationResult result;

  @override
  Widget build(BuildContext context) {
    final matched = result.difference.abs() < 0.005;
    final diffColor = matched ? AppColors.success : AppColors.warning;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Row(label: 'Ledger balance', value: result.ledgerBalance),
          const SizedBox(height: AppSpacing.sm),
          _Row(label: 'Statement balance', value: result.statementBalance),
          const Divider(height: AppSpacing.lg, color: AppColors.separator),
          Text('Difference',
              style: AppTypography.footnote
                  .copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.xs),
          Text(formatPkr(result.difference),
              style: AppTypography.title2
                  .copyWith(color: diffColor, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: AppTypography.subhead
                  .copyWith(color: AppColors.textMuted)),
        ),
        Text(formatPkr(value), style: AppTypography.subhead),
      ],
    );
  }
}

class _PriorTile extends StatelessWidget {
  const _PriorTile({required this.reconciliation});
  final BankReconciliation reconciliation;

  String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final completed = reconciliation.status.toUpperCase() == 'COMPLETED';
    final chipColor = completed ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.separator),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_day(reconciliation.statementDate),
                    style: AppTypography.subhead),
                const SizedBox(height: AppSpacing.xs),
                Text('Diff ${formatPkr(reconciliation.difference)}',
                    style: AppTypography.footnote
                        .copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            child: Text(reconciliation.status.toUpperCase(),
                style: AppTypography.caption
                    .copyWith(color: chipColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
