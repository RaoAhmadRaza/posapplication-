import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_money_field.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/no_access_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../sync/presentation/controllers/connectivity_controller.dart';
import '../../domain/entities/cart_line.dart';
import '../../domain/entities/customer.dart';
import '../controllers/pos_cart_controller.dart';
import '../widgets/sales_rise.dart';
import '../widgets/sales_scaffold.dart';

class PaymentSheet extends ConsumerStatefulWidget {
  const PaymentSheet({super.key, required this.branchId, required this.sessionId});

  final String branchId;
  final String? sessionId;

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentRow {
  _PaymentRow({this.method = PaymentMethodLabel.cash, required String? amount})
      : amountCtrl = TextEditingController(text: amount),
        refCtrl = TextEditingController();

  PaymentMethodLabel method;
  final TextEditingController amountCtrl;
  final TextEditingController refCtrl;
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

  /// Fills a tender with whatever is still owed, per the design's 'Exact' chip.
  void _fillExact(int i) {
    final remaining =
        _balance + (double.tryParse(_rows[i].amountCtrl.text) ?? 0);
    setState(() => _rows[i].amountCtrl.text = remaining.toStringAsFixed(0));
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
    final lum = context.lum;
    final cart = ref.watch(posCartProvider);
    final hasCustomer = cart.customer != null;
    final online = ref.watch(connectivityProvider).maybeWhen(data: (v) => v, orElse: () => true);

    return SalesScaffold(
      title: 'Payment',
      leading: _BackButton(
        onTap: _loading ? () {} : () => context.go('/sales/pos'),
      ),
      maxContentWidth: 560,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      bottomBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: lum.surface,
          border: Border(top: BorderSide(color: lum.hairline)),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: AppButton(
                label: _balance > 0 ? 'Charge · leave balance' : 'Complete sale',
                onPressed: _loading ? null : _complete,
                loading: _loading,
                fullWidth: true,
                icon: LucideIcons.check,
              ),
            ),
          ),
        ),
      ),
      child: SalesRise(
        duration: const Duration(milliseconds: 350),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  children: [
                    Text(
                      'Amount due',
                      style: AppTypography.footnote.copyWith(color: lum.g500),
                    ),
                    const SizedBox(height: 4),
                    AppMoneyText(_grand, size: 34),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _CustomerCard(customer: cart.customer),
              const SizedBox(height: 12),
              _OrderSummaryCard(cart: cart),
              const SizedBox(height: 22),
              if (!online) ...[
                const AppInlineBanner(
                  message: 'Offline — cash only. Collect the full amount; the '
                      'sale queues and syncs when back online.',
                  type: BannerType.info,
                ),
                const SizedBox(height: 14),
              ],
              Text(
                'TENDER',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: lum.g500,
                ),
              ),
              const SizedBox(height: 10),
              ...List.generate(
                _rows.length,
                (i) => _TenderRow(
                  row: _rows[i],
                  canRemove: _rows.length > 1,
                  cashOnly: !online,
                  onMethodChanged: (m) => setState(() => _rows[i].method = m),
                  onRemove: () => _removeRow(i),
                  onExact: () => _fillExact(i),
                  onAmountChanged: (_) => setState(() {}),
                ),
              ),
              AppButton(
                label: 'Add tender',
                onPressed: _addRow,
                variant: AppButtonVariant.plain,
                icon: LucideIcons.plus,
              ),
              if (_needsReference)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Reference is optional for non-cash payments.',
                    style: AppTypography.caption.copyWith(color: lum.g400),
                  ),
                ),
              const SizedBox(height: 18),
              _TotalLine(label: 'Paid', value: _paid),
              if (_change > 0)
                _TotalLine(
                  label: 'Change due',
                  value: _change,
                  color: lum.successText,
                ),
              if (_balance > 0)
                _TotalLine(
                  label: 'Remaining',
                  value: _balance,
                  color: lum.warningText,
                  strong: true,
                ),
              if (_balance > 0 && !hasCustomer) ...[
                const SizedBox(height: 12),
                const AppInlineBanner(
                  message: 'Credit requires a customer. Go back and select one.',
                  type: BannerType.info,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                AppInlineBanner(message: _error!),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tender: method, amount (with an 'Exact' shortcut) and an optional
/// reference for anything that is not cash.
class _TenderRow extends StatelessWidget {
  const _TenderRow({
    required this.row,
    required this.canRemove,
    required this.cashOnly,
    required this.onMethodChanged,
    required this.onRemove,
    required this.onExact,
    required this.onAmountChanged,
  });

  final _PaymentRow row;
  final bool canRemove;
  final bool cashOnly;
  final ValueChanged<PaymentMethodLabel> onMethodChanged;
  final VoidCallback onRemove;
  final VoidCallback onExact;
  final ValueChanged<String> onAmountChanged;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
                child: _MethodField(
                  value: cashOnly ? PaymentMethodLabel.cash : row.method,
                  enabled: !cashOnly,
                  onChanged: onMethodChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 6,
                child: AppMoneyField(
                  controller: row.amountCtrl,
                  fontSize: 20,
                  height: 50,
                  onChanged: onAmountChanged,
                  trailing: _ExactChip(onTap: onExact),
                ),
              ),
              if (canRemove)
                Semantics(
                  button: true,
                  label: 'Remove tender',
                  child: InkWell(
                    onTap: onRemove,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: SizedBox(
                      width: 36,
                      height: 44,
                      child: Icon(LucideIcons.x, size: 16, color: lum.g400),
                    ),
                  ),
                ),
            ],
          ),
          if (row.method != PaymentMethodLabel.cash) ...[
            const SizedBox(height: 10),
            AppTextField(
              controller: row.refCtrl,
              label: 'Reference (optional)',
              prefixIcon: LucideIcons.receiptText,
              hint: 'Transaction #',
            ),
          ],
        ],
      ),
    );
  }
}

class _ExactChip extends StatelessWidget {
  const _ExactChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      button: true,
      label: 'Fill exact remaining amount',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: lum.accentSoft,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            'Exact',
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: lum.accentPress,
            ),
          ),
        ),
      ),
    );
  }
}

/// Payment-method picker styled as a field rather than a Material dropdown box.
class _MethodField extends StatelessWidget {
  const _MethodField({
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final PaymentMethodLabel value;
  final ValueChanged<PaymentMethodLabel> onChanged;
  final bool enabled;

  static String labelOf(PaymentMethodLabel m) => switch (m) {
        PaymentMethodLabel.cash => 'Cash',
        PaymentMethodLabel.card => 'Card',
        PaymentMethodLabel.bankTransfer => 'Bank transfer',
        PaymentMethodLabel.mobileWallet => 'Mobile wallet',
        PaymentMethodLabel.cheque => 'Cheque',
        PaymentMethodLabel.loyaltyPoints => 'Loyalty points',
        PaymentMethodLabel.creditNote => 'Credit note',
      };

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final field = Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: enabled ? lum.surface : lum.surface2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: lum.hairline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<PaymentMethodLabel>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(AppRadius.md),
          icon: Icon(LucideIcons.chevronDown, size: 16, color: lum.g400),
          style: AppTypography.label.copyWith(color: lum.textPrimary),
          dropdownColor: lum.surface,
          onChanged: enabled
              ? (v) {
                  if (v != null) onChanged(v);
                }
              : null,
          items: [
            for (final m in PaymentMethodLabel.values)
              DropdownMenuItem(value: m, child: Text(labelOf(m))),
          ],
        ),
      ),
    );
    if (enabled) return field;
    return Tooltip(message: 'Offline: cash only', child: field);
  }
}

/// Who the sale is for. Shows the selected customer's identity, or a neutral
/// walk-in state when none was chosen at the register.
class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer});
  final Customer? customer;

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final c = customer;
    final walkIn = c == null;
    final title = walkIn ? 'Walk-in customer' : c.name;
    final subtitle = walkIn
        ? 'No account attached'
        : [c.phone, c.email].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: walkIn ? lum.g100 : lum.accentSoft,
            ),
            child: walkIn
                ? Icon(LucideIcons.user, size: 20, color: lum.g400)
                : Center(
                    child: Text(
                      _initials(c.name),
                      style: AppTypography.label.copyWith(
                        fontWeight: FontWeight.w700,
                        color: lum.accentPress,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w600,
                    color: lum.textPrimary,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(color: lum.g500),
                  ),
                ],
              ],
            ),
          ),
          if (!walkIn && c.loyaltyPoints > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: lum.accentSoft,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '${c.loyaltyPoints} pts',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: lum.accentPress,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Itemised order: every cart line, then the subtotal / discount / tax
/// breakdown that adds up to the amount due.
class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.cart});
  final CartState cart;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final lines = cart.lines;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ORDER SUMMARY',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: lum.g500,
                  ),
                ),
              ),
              Text(
                '${cart.totalItems} item${cart.totalItems == 1 ? '' : 's'}',
                style: AppTypography.caption.copyWith(color: lum.g500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final line in lines) _LineRow(line: line),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(height: 1, color: lum.hairline),
          ),
          _TotalLine(label: 'Subtotal', value: cart.subtotal),
          if (cart.discountTotal > 0)
            _TotalLine(
              label: 'Discount',
              value: -cart.discountTotal,
              color: lum.successText,
            ),
          _TotalLine(label: 'Tax', value: cart.taxTotal),
          const SizedBox(height: 2),
          _TotalLine(label: 'Total', value: cart.grandTotal, strong: true),
        ],
      ),
    );
  }
}

/// One product line: name + qty × unit price, with the line total right-aligned.
class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});
  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final qty = line.qty == line.qty.roundToDouble()
        ? line.qty.toStringAsFixed(0)
        : line.qty.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  line.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w500,
                    color: lum.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$qty × ${formatAmount(line.unitPrice, decimals: 0)}',
                  style: AppTypography.caption.copyWith(color: lum.g500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: AppMoneyText(line.lineTotal, size: 15),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      button: true,
      label: 'Back',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: SizedBox(
          width: 40,
          height: 44,
          child: Icon(LucideIcons.arrowLeft, size: 20, color: lum.g600),
        ),
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({
    required this.label,
    required this.value,
    this.color,
    this.strong = false,
  });

  final String label;
  final double value;
  final Color? color;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.body.copyWith(
                fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
                color: color ?? lum.g600,
              ),
            ),
          ),
          AppMoneyText(
            value,
            size: strong ? 18 : 15,
            color: color ?? lum.textPrimary,
          ),
        ],
      ),
    );
  }
}
