import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/failures/purchase_failure.dart';
import '../controllers/purchase_payments_controller.dart';
import 'supplier_picker_sheet.dart';

/// payment_method_enum DB values → display labels.
const _methods = <String, String>{
  'CASH': 'Cash',
  'BANK_TRANSFER': 'Bank Transfer',
  'CARD': 'Card',
  'MOBILE_WALLET': 'Mobile Wallet',
  'CHEQUE': 'Cheque',
  'LOYALTY_POINTS': 'Loyalty Points',
  'CREDIT_NOTE': 'Credit Note',
};

class SupplierPaymentPage extends ConsumerStatefulWidget {
  const SupplierPaymentPage({
    super.key,
    this.supplierId,
    this.invoiceId,
    this.presetAmount,
  });

  final String? supplierId;
  final String? invoiceId;
  final double? presetAmount;

  @override
  ConsumerState<SupplierPaymentPage> createState() =>
      _SupplierPaymentPageState();
}

class _SupplierPaymentPageState extends ConsumerState<SupplierPaymentPage> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  String _method = 'CASH';
  String? _supplierId;
  String? _supplierName;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _supplierId = widget.supplierId;
    if (widget.presetAmount != null && widget.presetAmount! > 0) {
      _amount.text = widget.presetAmount!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _pickSupplier() async {
    final supplier = await showSupplierPicker(context);
    if (supplier == null || !mounted) return;
    setState(() {
      _supplierId = supplier.id;
      _supplierName = supplier.name;
    });
  }

  Future<void> _submit() async {
    if (_supplierId == null) {
      setState(() => _error = 'Select a supplier.');
      return;
    }
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final reference = _reference.text.trim();
    final failure =
        await ref.read(purchasePaymentsProvider.notifier).recordPayment(
              supplierId: _supplierId!,
              invoiceId: widget.invoiceId,
              method: _method,
              amount: amount,
              reference: reference.isEmpty ? null : reference,
            );

    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _saving = false;
        if (failure is PurchaseOverpaymentFailure) {
          _error = failure.message;
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(failure.message)));
        }
      });
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Payment recorded')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text('Record Payment', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    if (_error != null) ...[
                      AppInlineBanner(
                          message: _error!, type: BannerType.error),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    _group('Supplier'),
                    _SupplierTile(
                      name: _supplierName,
                      supplierId: _supplierId,
                      // Fixed when supplied from the invoice; pickable otherwise.
                      onTap: widget.supplierId != null ? null : _pickSupplier,
                    ),
                    _sectionGap(),
                    _group('Invoice'),
                    _InvoiceTile(invoiceId: widget.invoiceId),
                    _sectionGap(),
                    _group('Method'),
                    _MethodDropdown(
                      value: _method,
                      onChanged: (m) => setState(() => _method = m),
                    ),
                    _sectionGap(),
                    _group('Amount'),
                    AppTextField(
                      controller: _amount,
                      label: 'Amount',
                      prefixIcon: Icons.attach_money,
                      hint: '0',
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                    _gap(),
                    AppTextField(
                      controller: _reference,
                      label: 'Reference',
                      prefixIcon: Icons.receipt_long,
                      hint: 'Optional',
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    PermissionGate(
                      module: 'purchase',
                      action: 'create',
                      child: AppButton(
                        label: 'Record Payment',
                        loading: _saving,
                        fullWidth: true,
                        icon: Icons.check,
                        onPressed: _submit,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gap() => const SizedBox(height: AppSpacing.fieldGap);
  Widget _sectionGap() => const SizedBox(height: AppSpacing.xl);

  Widget _group(String label) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(label.toUpperCase(),
            style: AppTypography.footnote.copyWith(
                color: AppColors.textMuted, fontWeight: FontWeight.w600)),
      );
}

class _SupplierTile extends StatelessWidget {
  const _SupplierTile({
    required this.name,
    required this.supplierId,
    required this.onTap,
  });
  final String? name;
  final String? supplierId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = name ??
        (supplierId != null ? 'Selected supplier' : 'Select a supplier');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(AppRadius.field),
          border: Border.all(color: AppColors.separator),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_shipping,
                size: 18, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: AppTypography.subhead)),
            if (onTap != null)
              const Icon(Icons.chevron_right,
                  size: 20, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({required this.invoiceId});
  final String? invoiceId;

  @override
  Widget build(BuildContext context) {
    final onAccount = invoiceId == null;
    final label = onAccount
        ? 'On account (no invoice)'
        : 'Invoice ${invoiceId!.substring(0, invoiceId!.length.clamp(0, 8))}';
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
          Icon(onAccount ? Icons.account_balance_wallet : Icons.receipt_long,
              size: 18, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: AppTypography.subhead)),
        ],
      ),
    );
  }
}

class _MethodDropdown extends StatelessWidget {
  const _MethodDropdown({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.separator),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down,
              size: 18, color: AppColors.textMuted),
          style: AppTypography.subhead,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          items: _methods.entries
              .map((e) =>
                  DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
        ),
      ),
    );
  }
}
