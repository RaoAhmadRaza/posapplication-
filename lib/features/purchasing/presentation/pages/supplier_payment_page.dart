import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_dropdown.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_money_field.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
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
          showAppToast(context, failure.message, type: BannerType.error);
        }
      });
      return;
    }
    showAppToast(context, 'Payment recorded', type: BannerType.success);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Fixed when supplied from the invoice; pickable otherwise.
    final locked = widget.supplierId != null;
    return AppDetailScaffold(
      eyebrow: 'Purchasing',
      title: 'Record payment',
      description: widget.invoiceId != null ? 'Against invoice' : 'On account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AppInlineBanner(message: _error!, type: BannerType.error),
            const SizedBox(height: 16),
          ],
          AppSectionCard(
            eyebrow: 'Supplier',
            child: _SupplierTile(
              name: _supplierName,
              supplierId: _supplierId,
              locked: locked,
              onTap: locked ? null : _pickSupplier,
            ),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            eyebrow: 'Invoice',
            child: _InvoiceTile(
              invoiceId: widget.invoiceId,
              balance: widget.presetAmount,
            ),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            eyebrow: 'Payment',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppDropdown<String>(
                  value: _method,
                  options: [
                    for (final e in _methods.entries)
                      AppDropdownOption(value: e.key, label: e.value),
                  ],
                  onSelected: (m) => setState(() => _method = m),
                ),
                const SizedBox(height: 14),
                AppMoneyField(controller: _amount, label: 'Amount'),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _reference,
                  label: 'Reference',
                  prefixIcon: LucideIcons.hash,
                  hint: 'Optional',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PermissionGate(
            module: 'purchase',
            action: 'create',
            child: AppButton(
              label: 'Record payment',
              loading: _saving,
              fullWidth: true,
              icon: LucideIcons.check,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplierTile extends StatelessWidget {
  const _SupplierTile({
    required this.name,
    required this.supplierId,
    required this.locked,
    required this.onTap,
  });
  final String? name;
  final String? supplierId;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final label = name ??
        (supplierId != null ? 'Selected supplier' : 'Select a supplier');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ClayContainer(
        variant: ClayVariant.inset,
        color: lum.surface2,
        borderRadius: AppRadius.md,
        isDark: lum.isDark,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(LucideIcons.truck, size: 18, color: lum.g500),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTypography.subhead.copyWith(color: lum.textPrimary),
              ),
            ),
            Icon(
              locked ? LucideIcons.lock : LucideIcons.chevronRight,
              size: locked ? 16 : 20,
              color: lum.g400,
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({required this.invoiceId, required this.balance});
  final String? invoiceId;
  final double? balance;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final onAccount = invoiceId == null;
    final label = onAccount
        ? 'On account (no invoice)'
        : 'Invoice ${invoiceId!.substring(0, invoiceId!.length.clamp(0, 8))}';
    final hasBalance = balance != null && balance! > 0;
    return ClayContainer(
      variant: ClayVariant.inset,
      color: lum.surface2,
      borderRadius: AppRadius.md,
      isDark: lum.isDark,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Icon(LucideIcons.receiptText, size: 18, color: lum.g500),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTypography.subhead.copyWith(color: lum.textPrimary),
            ),
          ),
          if (hasBalance)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppMoneyText(balance!, size: 17, color: lum.warningText),
                const SizedBox(height: 2),
                Text(
                  'balance',
                  style: AppTypography.caption.copyWith(
                    letterSpacing: 0.5,
                    color: lum.g400,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
