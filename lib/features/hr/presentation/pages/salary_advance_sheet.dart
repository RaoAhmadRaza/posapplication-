import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../controllers/advances_controller.dart';

/// Give-advance sheet (Dr 1150 / Cr pay account via disburse_salary_advance).
/// Gated by the caller (hr:approve). Returns true on success.
Future<bool> showGiveAdvanceSheet({
  required BuildContext context,
  required String employeeId,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    builder: (_) => _GiveAdvanceSheet(employeeId: employeeId),
  );
  return result ?? false;
}

class _GiveAdvanceSheet extends ConsumerStatefulWidget {
  const _GiveAdvanceSheet({required this.employeeId});
  final String employeeId;

  @override
  ConsumerState<_GiveAdvanceSheet> createState() => _GiveAdvanceSheetState();
}

class _GiveAdvanceSheetState extends ConsumerState<_GiveAdvanceSheet> {
  final _amountCtrl = TextEditingController();
  final _recoveryCtrl = TextEditingController();
  final _payCtrl = TextEditingController(text: '1000');
  final _notesCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _recoveryCtrl.dispose();
    _payCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    final recovery = double.tryParse(_recoveryCtrl.text.trim());
    final pay = _payCtrl.text.trim().isEmpty ? '1000' : _payCtrl.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    final failure = await ref.read(advanceActionsProvider).disburse({
      'p_employee_id': widget.employeeId,
      'p_amount': amount,
      'p_recovery_amount': recovery, // null → server defaults to full amount
      'p_pay_account': pay,
      'p_notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    }, widget.employeeId);
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _saving = false;
        _error = failure.message;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Give Advance', style: AppTypography.headline),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
                controller: _amountCtrl,
                label: 'Amount',
                prefixIcon: Icons.payments_outlined,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
                controller: _recoveryCtrl,
                label: 'Recovery per payroll (optional)',
                prefixIcon: Icons.trending_down,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
                controller: _payCtrl,
                label: 'Pay account code',
                prefixIcon: Icons.account_balance_outlined),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
                controller: _notesCtrl,
                label: 'Notes (optional)',
                prefixIcon: Icons.notes),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppInlineBanner(message: _error!, type: BannerType.error),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
                label: 'Disburse Advance',
                fullWidth: true,
                loading: _saving,
                onPressed: _saving ? null : _save),
          ],
        ),
      ),
    );
  }
}
