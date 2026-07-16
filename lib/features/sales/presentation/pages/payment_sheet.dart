import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/no_access_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../sync/presentation/controllers/connectivity_controller.dart';
import '../controllers/pos_cart_controller.dart';

class PaymentSheet extends ConsumerStatefulWidget {
  const PaymentSheet({super.key, required this.branchId, required this.sessionId});

  final String branchId;
  final String? sessionId;

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentRow {
  PaymentMethodLabel method;
  final TextEditingController amountCtrl;
  final TextEditingController refCtrl;

  _PaymentRow({this.method = PaymentMethodLabel.cash, required String? amount})
      : amountCtrl = TextEditingController(text: amount),
        refCtrl = TextEditingController();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  final List<_PaymentRow> _rows = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final grand = ref.read(posCartProvider).grandTotal;
    _rows.add(_PaymentRow(method: PaymentMethodLabel.cash, amount: grand.toStringAsFixed(0)));
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.amountCtrl.dispose();
      r.refCtrl.dispose();
    }
    super.dispose();
  }

  double get _paid {
    double total = 0;
    for (final r in _rows) {
      total += double.tryParse(r.amountCtrl.text) ?? 0;
    }
    return total;
  }

  double get _grand => ref.watch(posCartProvider).grandTotal;
  double get _balance => (_grand - _paid).clamp(0, double.infinity);
  double get _change => (_paid - _grand).clamp(0, double.infinity);

  void _addRow() {
    setState(() => _rows.add(_PaymentRow(method: PaymentMethodLabel.cash, amount: null)));
  }

  void _removeRow(int i) {
    if (_rows.length <= 1) return;
    setState(() {
      _rows[i].amountCtrl.dispose();
      _rows[i].refCtrl.dispose();
      _rows.removeAt(i);
    });
  }

  bool get _needsReference {
    for (final r in _rows) {
      if (r.method != PaymentMethodLabel.cash) return true;
    }
    return false;
  }

  Future<void> _complete() async {
    final cart = ref.read(posCartProvider);
    final online = ref.read(connectivityProvider).maybeWhen(data: (v) => v, orElse: () => true);
    if (_paid <= 0) {
      setState(() => _error = 'Enter at least one payment.');
      return;
    }
    // Offline is CASH-ONLY BY CONSTRUCTION: no credit (no server credit-limit check),
    // full amount required, no non-cash tender (no bank/GL resolution offline).
    if (!online) {
      if (_rows.any((r) => r.method != PaymentMethodLabel.cash)) {
        setState(() => _error = 'Offline: cash only. Remove non-cash payment methods.');
        return;
      }
      if (_balance > 0) {
        setState(() => _error = 'Offline: cash only. Collect the full amount (no credit).');
        return;
      }
    }
    if (_balance > 0 && cart.customer == null) {
      setState(() => _error = 'Credit sales require a customer. Select a customer first.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final notifier = ref.read(posCartProvider.notifier);
    notifier.clearResult();
    for (final r in _rows) {
      final amt = double.tryParse(r.amountCtrl.text) ?? 0;
      if (amt > 0) {
        notifier.addPayment(r.method, amt, reference: r.refCtrl.text.isNotEmpty ? r.refCtrl.text : null);
      }
    }

    final failure = await notifier.checkout(
      branchId: widget.branchId,
      sessionId: widget.sessionId,
      offline: !online,
    );

    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _loading = false;
        _error = failure.message;
      });
    } else {
      context.go('/sales/success');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      module: 'sales',
      action: 'create',
      fallback: const NoAccessScaffold(),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final hasCustomer = ref.watch(posCartProvider).customer != null;
    final online = ref.watch(connectivityProvider).maybeWhen(data: (v) => v, orElse: () => true);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text('Payment', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    _SummaryBox(label: 'Grand Total', value: _grand, bold: true),
                    const SizedBox(height: AppSpacing.xl),
                    if (!online)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: AppInlineBanner(
                          message: 'Offline — cash only. Collect the full amount; the sale queues and syncs when back online.',
                          type: BannerType.info,
                        ),
                      ),
                    ...List.generate(_rows.length, (i) => _PaymentRowWidget(
                          row: _rows[i],
                          index: i,
                          canRemove: _rows.length > 1,
                          cashOnly: !online,
                          onMethodChanged: (m) => setState(() => _rows[i].method = m),
                          onRemove: () => _removeRow(i),
                        )),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: '+ Add Payment',
                      onPressed: _addRow,
                      variant: AppButtonVariant.plain,
                      icon: Icons.add,
                    ),
                    if (_needsReference)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          'Reference is optional for non-cash payments.',
                          style: AppTypography.caption.copyWith(color: AppColors.textHint),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xl),
                    _SummaryBox(label: 'Paid', value: _paid),
                    if (_change > 0)
                      _SummaryBox(label: 'Change', value: _change, color: AppColors.success),
                    if (_balance > 0)
                      _SummaryBox(label: 'Balance Due', value: _balance, color: AppColors.warning),
                    if (_balance > 0 && !hasCustomer)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: AppInlineBanner(
                          message: 'Credit requires a customer. Go back and select one.',
                          type: BannerType.info,
                        ),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      AppInlineBanner(message: _error!, type: BannerType.error),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.md, AppSpacing.screenPadding, AppSpacing.xxl),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(top: BorderSide(color: AppColors.separator, width: 0.5)),
              ),
              child: AppButton(
                label: _balance > 0 ? 'Charge (Leave Balance)' : 'Complete Sale',
                onPressed: _loading ? null : _complete,
                loading: _loading,
                fullWidth: true,
                icon: Icons.check,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentRowWidget extends StatelessWidget {
  const _PaymentRowWidget({
    required this.row,
    required this.index,
    required this.canRemove,
    required this.cashOnly,
    required this.onMethodChanged,
    required this.onRemove,
  });

  final _PaymentRow row;
  final int index;
  final bool canRemove;
  final bool cashOnly;
  final ValueChanged<PaymentMethodLabel> onMethodChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MethodDropdown(
                  value: cashOnly ? PaymentMethodLabel.cash : row.method,
                  enabled: !cashOnly,
                  onChanged: onMethodChanged,
                ),
              ),
              if (canRemove)
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: AppColors.textHint),
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: row.amountCtrl,
            label: 'Amount',
            prefixIcon: Icons.attach_money,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            hint: '0',
          ),
          if (row.method != PaymentMethodLabel.cash) ...[
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: row.refCtrl,
              label: 'Reference (optional)',
              prefixIcon: Icons.receipt_long,
              hint: 'Transaction #',
            ),
          ],
        ],
      ),
    );
  }
}

class _MethodDropdown extends StatelessWidget {
  const _MethodDropdown({required this.value, required this.onChanged, this.enabled = true});
  final PaymentMethodLabel value;
  final ValueChanged<PaymentMethodLabel> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final dropdown = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: enabled ? AppColors.background : AppColors.fieldFill,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.separator),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<PaymentMethodLabel>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textMuted),
          style: AppTypography.subhead,
          onChanged: enabled ? (v) { if (v != null) onChanged(v); } : null,
          items: PaymentMethodLabel.values.map((m) {
            return DropdownMenuItem(
              value: m,
              child: Text(
                switch (m) {
                  PaymentMethodLabel.cash => 'Cash',
                  PaymentMethodLabel.card => 'Card',
                  PaymentMethodLabel.bankTransfer => 'Bank Transfer',
                  PaymentMethodLabel.mobileWallet => 'Mobile Wallet',
                  PaymentMethodLabel.cheque => 'Cheque',
                  PaymentMethodLabel.loyaltyPoints => 'Loyalty Points',
                  PaymentMethodLabel.creditNote => 'Credit Note',
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
    if (enabled) return dropdown;
    return Tooltip(message: 'Offline: cash only', child: dropdown);
  }
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({required this.label, required this.value, this.bold = false, this.color});
  final String label;
  final double value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: color != null ? Border.all(color: color!.withValues(alpha: 0.3)) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.subhead.copyWith(color: AppColors.textMuted)),
          Text(
            formatPkr(value),
            style: (bold ? AppTypography.headline : AppTypography.subhead).copyWith(
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
