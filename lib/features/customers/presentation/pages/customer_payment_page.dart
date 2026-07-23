import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_filter_chips.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/widgets/module_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/customer_invoice.dart';
import '../../domain/failures/customer_failure.dart';
import '../controllers/customer_payments_controller.dart';
import '../widgets/customer_card.dart';

/// payment_method_enum DB values, in the design's chip order.
const _methodKeys = ['CASH', 'BANK_TRANSFER', 'CARD', 'MOBILE_WALLET', 'CHEQUE'];
const _methodLabels = ['Cash', 'Bank transfer', 'Card', 'Mobile wallet',
  'Cheque'];

/// Collect a payment against a customer's credit invoice
/// (record_customer_payment).
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
      setState(() => _error = 'Choose an invoice to apply this payment to.');
      return;
    }
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
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
          showAppToast(context, failure.message, type: BannerType.error);
        }
      });
      return;
    }
    final balance = result?.balance ?? 0;
    final status = result?.status ?? '';
    showAppToast(
      context,
      'Payment recorded — balance ${formatPkr(balance)}'
      '${status.isEmpty ? '' : ' ($status)'}',
      type: BannerType.success,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = ModuleScaffold.isWideOf(context);
    final fixedInvoice = widget.invoiceId != null;

    return ModuleScaffold(
      title: 'Collect payment',
      maxContentWidth: 640,
      leading: _FormBackButton(),
      child: ListView(
        padding:
            EdgeInsets.fromLTRB(isWide ? 32 : 16, 12, isWide ? 32 : 16, 40),
        children: [
          if (widget.customerName != null) ...[
            _CustomerHeader(name: widget.customerName!),
            const SizedBox(height: 16),
          ],
          _Section(
            title: 'Apply to invoice',
            child: fixedInvoice
                ? _FixedInvoiceTile(balance: _invoiceBalance)
                : _InvoicePicker(
                    customerId: widget.customerId,
                    selectedId: _invoiceId,
                    onSelect: _selectInvoice,
                  ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Payment',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Label('Method'),
                const SizedBox(height: 8),
                AppFilterChips(
                  labels: _methodLabels,
                  selected: _methodKeys.indexOf(_method),
                  onSelected: (i) =>
                      setState(() => _method = _methodKeys[i]),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _amount,
                        label: 'Amount',
                        prefixIcon: LucideIcons.banknote,
                        hint: '0.00',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AppTextField(
                        controller: _reference,
                        label: 'Reference',
                        prefixIcon: LucideIcons.hash,
                        hint: 'Optional',
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  AppInlineBanner(message: _error!, type: BannerType.error),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          PermissionGate(
            module: 'sales',
            action: 'create',
            child: AppButton(
              label: 'Record payment',
              icon: LucideIcons.checkCheck,
              loading: _saving,
              fullWidth: true,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}

/// Customer header — avatar + name. Outstanding/phone are not passed to this
/// route, so nothing is invented for them.
class _CustomerHeader extends StatelessWidget {
  const _CustomerHeader({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return AppCard(
      child: Row(
        children: [
          ClayContainer(
            variant: ClayVariant.soft,
            color: lum.accentSoft,
            borderRadius: AppRadius.md,
            isDark: lum.isDark,
            width: 48,
            height: 48,
            child: Center(
              child: Text(
                customerInitials(name),
                style: AppTypography.title2
                    .copyWith(fontSize: 16, color: lum.accentPress),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              name,
              style: AppTypography.headline
                  .copyWith(fontSize: 16, color: lum.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _FixedInvoiceTile extends StatelessWidget {
  const _FixedInvoiceTile({required this.balance});
  final double? balance;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: lum.surface2,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.receiptText, size: 18, color: lum.g500),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Selected invoice',
              style: AppTypography.body.copyWith(color: lum.textPrimary),
            ),
          ),
          if (balance != null)
            AppMoneyText(balance!,
                size: 14, decimals: 2, color: lum.textPrimary),
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
    final lum = context.lum;
    final invoicesAsync = ref.watch(unpaidInvoicesProvider(customerId));
    return invoicesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppInlineBanner(
          message:
              e is CustomerFailure ? e.message : 'Failed to load invoices.',
          type: BannerType.error),
      data: (invoices) {
        if (invoices.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: Text('No unpaid invoices.',
                  style: AppTypography.body.copyWith(color: lum.g500)),
            ),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < invoices.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _InvoiceRow(
                invoice: invoices[i],
                selected: invoices[i].id == selectedId,
                onTap: () => onSelect(invoices[i]),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.invoice,
    required this.selected,
    required this.onTap,
  });
  final CustomerInvoice invoice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      button: true,
      selected: selected,
      label: invoice.invoiceNumber,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? lum.accentSoft : lum.surface2,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? lum.accent : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? LucideIcons.circleCheck
                    : LucideIcons.circle,
                size: 20,
                color: selected ? lum.accent : lum.g400,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  invoice.invoiceNumber,
                  style: AppTypography.monoValue.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: lum.textPrimary,
                  ),
                ),
              ),
              AppMoneyText(invoice.balance,
                  size: 14, decimals: 2, color: lum.textPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: AppTypography.title2
                .copyWith(fontSize: 16, color: lum.textPrimary),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Text(
      text,
      style: AppTypography.fieldLabel.copyWith(fontSize: 13, color: lum.g700),
    );
  }
}

class _FormBackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Semantics(
        button: true,
        label: 'Back',
        child: InkWell(
          onTap: () => Navigator.of(context).maybePop(),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: ClayContainer(
                variant: ClayVariant.soft,
                color: lum.surface,
                borderRadius: AppRadius.sm,
                isDark: lum.isDark,
                width: 40,
                height: 40,
                child: Center(
                  child: Icon(LucideIcons.arrowLeft,
                      size: 20, color: lum.textPrimary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
