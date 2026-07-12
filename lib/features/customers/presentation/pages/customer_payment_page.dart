import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/customer_invoice.dart';
import '../../domain/failures/customer_failure.dart';
import '../controllers/customer_payments_controller.dart';

/// payment_method_enum DB values → display labels.
const _methods = <String, String>{
  'CASH': 'Cash',
  'BANK_TRANSFER': 'Bank Transfer',
  'CARD': 'Card',
  'MOBILE_WALLET': 'Mobile Wallet',
  'CHEQUE': 'Cheque',
};

/// Collect a payment against a customer's credit invoice (record_customer_payment).
class CustomerPaymentPage extends ConsumerStatefulWidget {
  const CustomerPaymentPage({
    super.key,
    required this.customerId,
    this.customerName,
    this.invoiceId,
    this.presetAmount,
  });

  final String customerId;
  final String? customerName;
  final String? invoiceId;
  final double? presetAmount;

  @override
  ConsumerState<CustomerPaymentPage> createState() =>
      _CustomerPaymentPageState();
}

class _CustomerPaymentPageState extends ConsumerState<CustomerPaymentPage> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  String _method = 'CASH';
  String? _invoiceId;
  double? _invoiceBalance;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _invoiceId = widget.invoiceId;
    _invoiceBalance = widget.presetAmount;
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

  void _selectInvoice(CustomerInvoice invoice) {
    setState(() {
      _invoiceId = invoice.id;
      _invoiceBalance = invoice.balance;
      _amount.text = invoice.balance.toStringAsFixed(0);
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_invoiceId == null) {
      setState(() => _error = 'Select an invoice to collect against.');
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
    final (result, failure) =
        await ref.read(customerPaymentsProvider.notifier).recordPayment(
              customerId: widget.customerId,
              invoiceId: _invoiceId!,
              method: _method,
              amount: amount,
              reference: reference.isEmpty ? null : reference,
            );

    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _saving = false;
        if (failure is CustomerOverpaymentFailure) {
          _error = failure.message;
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(failure.message)));
        }
      });
      return;
    }
    final balance = result?.balance ?? 0;
    final status = result?.status ?? '';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Payment recorded — balance ${formatPkr(balance)}'
            '${status.isEmpty ? '' : ' ($status)'}')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final fixedInvoice = widget.invoiceId != null;
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
        title: Text('Collect Payment', style: AppTypography.headline),
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
                    if (widget.customerName != null) ...[
                      _group('Customer'),
                      _InfoTile(
                          icon: Icons.person,
                          label: widget.customerName!),
                      _sectionGap(),
                    ],
                    _group('Invoice'),
                    if (fixedInvoice)
                      _InfoTile(
                        icon: Icons.receipt_long,
                        label: _invoiceBalance != null
                            ? 'Balance ${formatPkr(_invoiceBalance!)}'
                            : 'Selected invoice',
                      )
                    else
                      _InvoicePicker(
                        customerId: widget.customerId,
                        selectedId: _invoiceId,
                        onSelect: _selectInvoice,
                      ),
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
                      module: 'sales',
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

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
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
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: AppTypography.subhead)),
        ],
      ),
    );
  }
}

class _InvoicePicker extends ConsumerWidget {
  const _InvoicePicker({
    required this.customerId,
    required this.selectedId,
    required this.onSelect,
  });
  final String customerId;
  final String? selectedId;
  final ValueChanged<CustomerInvoice> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(unpaidInvoicesProvider(customerId));
    return invoicesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppInlineBanner(
          message: e is CustomerFailure ? e.message : 'Failed to load invoices.',
          type: BannerType.error),
      data: (invoices) {
        if (invoices.isEmpty) {
          return const _InfoTile(
              icon: Icons.check_circle_outline,
              label: 'No unpaid invoices.');
        }
        return Column(
          children: [
            for (final inv in invoices)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: InkWell(
                  onTap: () => onSelect(inv),
                  borderRadius: BorderRadius.circular(AppRadius.field),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.base, vertical: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.fieldFill,
                      borderRadius: BorderRadius.circular(AppRadius.field),
                      border: Border.all(
                        color: inv.id == selectedId
                            ? AppColors.accent
                            : AppColors.separator,
                        width: inv.id == selectedId ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          inv.id == selectedId
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 18,
                          color: inv.id == selectedId
                              ? AppColors.accent
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(inv.invoiceNumber,
                              style: AppTypography.subhead),
                        ),
                        Text(formatPkr(inv.balance),
                            style: AppTypography.subhead.copyWith(
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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
