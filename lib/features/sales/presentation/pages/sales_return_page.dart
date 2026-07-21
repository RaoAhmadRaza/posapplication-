import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_checkbox.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_money_field.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_filter_chips.dart';
import '../../../../core/design/widgets/app_qty_stepper.dart';
import '../../../../core/services/scanner_support.dart';
import '../../../../core/widgets/barcode_scan_page.dart';
import '../../../../core/widgets/no_access_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/customer.dart';
import '../controllers/customers_controller.dart';
import '../controllers/invoices_controller.dart';
import '../widgets/sales_empty_state.dart';
import '../widgets/sales_rise.dart';
import '../widgets/sales_scaffold.dart';

class SalesReturnPage extends ConsumerStatefulWidget {
  const SalesReturnPage({super.key});

  @override
  ConsumerState<SalesReturnPage> createState() => _SalesReturnPageState();
}

class _SalesReturnPageState extends ConsumerState<SalesReturnPage> {
  final _searchCtrl = TextEditingController();
  Map<String, dynamic>? _invoiceDetail;
  final Map<String, double> _returnQtys = {};
  final Map<String, double> _maxQtys = {};
  String _reason = '';
  bool _loading = false;
  String? _error;
  String? _successMessage;
  final _refundCtrl = TextEditingController();

  final List<String> _returnReasons = [
    'Defective',
    'Wrong Item',
    'Not as Described',
    'Customer Changed Mind',
    'Damaged in Transit',
    'Other',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _refundCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookupInvoice() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _invoiceDetail = null;
      _returnQtys.clear();
      _maxQtys.clear();
    });

    final detail = await ref.read(invoicesProvider.notifier).loadDetail(q);
    if (!mounted) return;

    if (detail == null) {
      final invoices = ref.read(invoicesProvider).value ?? [];
      if (invoices.isNotEmpty) {
        final match = invoices.where(
          (i) => q.isNotEmpty && (i.invoiceNumber.toLowerCase().contains(q.toLowerCase()) || i.id == q),
        ).firstOrNull;
        if (match != null) {
          final detail2 = await ref.read(invoicesProvider.notifier).loadDetail(match.id);
          if (mounted && detail2 != null) {
            _setupReturnItems(detail2);
            return;
          }
        }
      }
      setState(() {
        _loading = false;
        _error = 'No matching invoice. Scan the barcode or check the number.';
      });
      return;
    }

    _setupReturnItems(detail);
  }

  void _setupReturnItems(Map<String, dynamic> detail) {
    final items = (detail['invoice_items'] as List<dynamic>?) ?? [];
    final status = (detail['status']?.toString() ?? '').toUpperCase();
    if (status == 'RETURNED' || status == 'VOID') {
      setState(() {
        _loading = false;
        _error = 'This invoice is already $status.';
      });
      return;
    }

    for (final item in items) {
      final itemMap = item as Map<String, dynamic>;
      final itemId = itemMap['id'] as String;
      final qty = double.tryParse(itemMap['qty']?.toString() ?? '0') ?? 0;
      _maxQtys[itemId] = qty;
      _returnQtys[itemId] = 0;
    }

    final grand = double.tryParse(detail['grand_total']?.toString() ?? '0') ?? 0;
    _refundCtrl.text = grand.toStringAsFixed(0);

    setState(() {
      _invoiceDetail = detail;
      _loading = false;
      _error = null;
      _successMessage = null;
    });
  }

  Future<void> _scanInvoice() async {
    final code = await scanBarcode(context, title: 'Scan Invoice');
    if (code == null || code == BarcodeScanPage.manualEntrySentinel) return;
    _searchCtrl.text = code;
    _lookupInvoice();
  }

  Future<void> _submitReturn() async {
    if (_invoiceDetail == null) return;
    final returnItems = <Map<String, dynamic>>[];
    _returnQtys.forEach((id, qty) {
      if (qty > 0) {
        returnItems.add({'invoice_item_id': id, 'qty': qty});
      }
    });

    if (returnItems.isEmpty) {
      setState(() => _error = 'Select at least one item to return.');
      return;
    }
    if (_reason.isEmpty) {
      setState(() => _error = 'Select a return reason.');
      return;
    }
    final refundAmt = double.tryParse(_refundCtrl.text) ?? 0;
    final refunds = <Map<String, dynamic>>[];
    if (refundAmt > 0) {
      refunds.add({'method': 'CASH', 'amount': refundAmt});
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final (result, failure) = await ref.read(invoicesProvider.notifier).doReturn(
          originalInvoiceId: _invoiceDetail!['id'] as String,
          items: returnItems,
          reason: _reason,
          refunds: refunds,
        );

    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _loading = false;
        _error = failure.message;
      });
    } else {
      setState(() {
        _loading = false;
        _successMessage = 'Return processed: ${result?.invoiceNumber ?? ''}';
        _invoiceDetail = null;
        _returnQtys.clear();
        _searchCtrl.clear();
      });
    }
  }

  /// Value of the lines currently ticked, shown beside the editable refund.
  double get _selectedValue {
    final items = (_invoiceDetail?['invoice_items'] as List<dynamic>?) ?? [];
    var total = 0.0;
    for (final raw in items) {
      final item = raw as Map<String, dynamic>;
      final qty = _returnQtys[item['id'] as String] ?? 0;
      final unit = double.tryParse(item['unit_price']?.toString() ?? '0') ?? 0;
      total += qty * unit;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      module: 'sales',
      action: 'update',
      fallback: const NoAccessScaffold(),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final lum = context.lum;
    final customers = ref.watch(customersProvider).value ?? <Customer>[];
    final detail = _invoiceDetail;

    return SalesScaffold(
      title: 'Sales return',
      maxContentWidth: 760,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find the original invoice',
                    style: AppTypography.footnote.copyWith(
                      fontWeight: FontWeight.w600,
                      color: lum.g600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _LookupField(controller: _searchCtrl, onSubmit: _lookupInvoice)),
                      if (barcodeScanSupported) ...[
                        const SizedBox(width: 10),
                        _SquareAction(
                          icon: LucideIcons.scanLine,
                          label: 'Scan invoice',
                          onTap: _scanInvoice,
                        ),
                      ],
                      const SizedBox(width: 10),
                      AppButton(
                        label: 'Look up',
                        onPressed: _loading ? null : _lookupInvoice,
                        loading: _loading,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              AppInlineBanner(message: _error!),
            ],
            if (_successMessage != null) ...[
              const SizedBox(height: 14),
              SalesRise(
                duration: const Duration(milliseconds: 300),
                child: AppCard(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: lum.successSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.check,
                          size: 26,
                          color: lum.successText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Return processed', style: AppTypography.title3),
                      const SizedBox(height: 6),
                      Text(
                        '$_successMessage. Stock has been added back.',
                        textAlign: TextAlign.center,
                        style: AppTypography.footnote.copyWith(
                          height: 1.5,
                          color: lum.g500,
                        ),
                      ),
                      const SizedBox(height: 18),
                      AppButton(
                        label: 'View history',
                        onPressed: () => context.go('/sales/history'),
                        variant: AppButtonVariant.plain,
                        fullWidth: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (detail == null && _successMessage == null && _error == null)
              const SalesEmptyState(
                icon: LucideIcons.rotateCcw,
                message: 'Look up an invoice to start a return.',
              ),
            if (detail != null) ...[
              const SizedBox(height: 14),
              _InvoiceHeader(detail: detail, customers: customers),
              const SizedBox(height: 14),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    for (final raw in detail['invoice_items'] as List<dynamic>)
                      _ReturnItemRow(
                        item: raw as Map<String, dynamic>,
                        returnQty: _returnQtys[raw['id'] as String] ?? 0,
                        maxQty: _maxQtys[raw['id'] as String] ?? 0,
                        onChanged: (qty) => setState(
                          () => _returnQtys[raw['id'] as String] = qty,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'REASON',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: lum.g500,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // create_sales_return requires a reason; the design has no
                  // reason control, so it stays and is styled to match.
                  for (final r in _returnReasons)
                    AppFilterChip(
                      label: r,
                      active: _reason == r,
                      onTap: () =>
                          setState(() => _reason = _reason == r ? '' : r),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Selected items',
                            style: AppTypography.footnote
                                .copyWith(color: lum.g500),
                          ),
                        ),
                        AppMoneyText(_selectedValue, size: 15),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppMoneyField(
                      controller: _refundCtrl,
                      label: 'Refund amount',
                      fontSize: 24,
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Process return',
                      onPressed: _loading ? null : _submitReturn,
                      loading: _loading,
                      fullWidth: true,
                      icon: LucideIcons.rotateCcw,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

/// Mono invoice-number field in the lookup card.
class _LookupField extends StatelessWidget {
  const _LookupField({required this.controller, required this.onSubmit});
  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return ClayContainer(
      variant: ClayVariant.inset,
      color: lum.surface2,
      borderRadius: AppRadius.md,
      isDark: lum.isDark,
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 18, color: lum.g400),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSubmit(),
              cursorColor: lum.accent,
              style: AppTypography.monoValue.copyWith(
                fontSize: 14,
                color: lum.textPrimary,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'Invoice number, e.g. INV-1042',
                hintStyle: AppTypography.monoValue.copyWith(
                  fontSize: 14,
                  color: lum.textTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SquareAction extends StatelessWidget {
  const _SquareAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ClayContainer(
          variant: ClayVariant.soft,
          color: lum.surface,
          borderRadius: AppRadius.md,
          isDark: lum.isDark,
          width: 50,
          height: 50,
          child: Icon(icon, size: 22, color: lum.textPrimary),
        ),
      ),
    );
  }
}

class _InvoiceHeader extends StatelessWidget {
  const _InvoiceHeader({required this.detail, required this.customers});
  final Map<String, dynamic> detail;
  final List<Customer> customers;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final number = detail['invoice_number']?.toString() ?? '';
    final createdAt = DateTime.tryParse(detail['created_at']?.toString() ?? '');
    final dateStr = createdAt == null
        ? ''
        : '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    final customerId = detail['customer_id']?.toString();
    final customerName = customerId != null
        ? customers.where((c) => c.id == customerId).firstOrNull?.name ?? 'Walk-in'
        : 'Walk-in';
    final grand = double.tryParse(detail['grand_total']?.toString() ?? '0') ?? 0;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  number,
                  style: AppTypography.monoValue.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: lum.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [customerName, if (dateStr.isNotEmpty) dateStr].join(' · '),
                  style: AppTypography.footnote.copyWith(color: lum.g500),
                ),
              ],
            ),
          ),
          AppMoneyText(grand, size: 18),
        ],
      ),
    );
  }
}

class _ReturnItemRow extends StatelessWidget {
  const _ReturnItemRow({
    required this.item,
    required this.returnQty,
    required this.maxQty,
    required this.onChanged,
  });

  final Map<String, dynamic> item;
  final double returnQty;
  final double maxQty;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final desc = item['description']?.toString() ?? 'Item';
    final unitPrice = double.tryParse(item['unit_price']?.toString() ?? '0') ?? 0;
    final active = returnQty > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          AppCheckbox(
            value: active,
            onChanged: (checked) => onChanged(checked ? 1 : 0),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  desc.isEmpty ? 'Item' : desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(color: lum.textPrimary),
                ),
                Text(
                  'bought ${maxQty.toStringAsFixed(0)} · '
                  '${formatPkr(unitPrice)} each',
                  style: AppTypography.monoValue.copyWith(
                    fontSize: 11.5,
                    color: lum.g500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppQtyStepper(
            value: returnQty.round(),
            min: 1,
            max: maxQty.round(),
            enabled: active,
            onChanged: (q) => onChanged(q.toDouble()),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Align(
              alignment: Alignment.centerRight,
              child: AppMoneyText(
                returnQty * unitPrice,
                size: 13.5,
                color: active ? lum.textPrimary : lum.g400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
