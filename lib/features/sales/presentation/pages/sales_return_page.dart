import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/services/scanner_support.dart';
import '../../../../core/widgets/barcode_scan_page.dart';
import '../../../../core/widgets/no_access_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/customer.dart';
import '../controllers/customers_controller.dart';
import '../controllers/invoices_controller.dart';

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
        _error = 'Invoice not found. Scan barcode or enter invoice number.';
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
    final customers = ref.watch(customersProvider).value ?? <Customer>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text('Sales Return', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _searchCtrl,
                      label: 'Invoice Number',
                      prefixIcon: Icons.search,
                      hint: 'Scan or type invoice number',
                      onSubmitted: (_) => _lookupInvoice(),
                    ),
                  ),
                  if (barcodeScanSupported) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.field),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.qr_code_scanner, color: AppColors.accent, size: 22),
                        onPressed: _scanInvoice,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Look Up',
                onPressed: _loading ? null : _lookupInvoice,
                loading: _loading,
                fullWidth: true,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppInlineBanner(message: _error!, type: BannerType.error),
              ],
              if (_successMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppInlineBanner(message: _successMessage!, type: BannerType.success),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'View History',
                  onPressed: () => context.go('/sales/history'),
                  fullWidth: true,
                  variant: AppButtonVariant.plain,
                ),
              ],
              if (_invoiceDetail != null) ...[
                const SizedBox(height: AppSpacing.xl),
                _InvoiceHeader(detail: _invoiceDetail!, customers: customers),
                const SizedBox(height: AppSpacing.xl),
                Text('Select Items to Return', style: AppTypography.headline),
                const SizedBox(height: AppSpacing.sm),
                ...(_invoiceDetail!['invoice_items'] as List<dynamic>).map(
                  (item) => _ReturnItemRow(
                    item: item as Map<String, dynamic>,
                    returnQty: _returnQtys[item['id'] as String] ?? 0,
                    maxQty: _maxQtys[item['id'] as String] ?? 0,
                    onChanged: (qty) => setState(() => _returnQtys[item['id'] as String] = qty),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Return Reason', style: AppTypography.headline),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _returnReasons.map((r) {
                    final active = _reason == r;
                    return GestureDetector(
                      onTap: () => setState(() => _reason = active ? '' : r),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: active ? AppColors.accent.withValues(alpha: 0.1) : AppColors.fieldFill,
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                          border: active ? Border.all(color: AppColors.accent, width: 1) : null,
                        ),
                        child: Text(r, style: AppTypography.footnote.copyWith(
                          color: active ? AppColors.accent : AppColors.textMuted,
                        )),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppTextField(
                  controller: _refundCtrl,
                  label: 'Refund Amount',
                  prefixIcon: Icons.attach_money,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  hint: '0',
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppButton(
                  label: 'Process Return',
                  onPressed: _loading ? null : _submitReturn,
                  loading: _loading,
                  fullWidth: true,
                  variant: AppButtonVariant.destructive,
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
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
    final number = detail['invoice_number']?.toString() ?? '';
    final createdAt = detail['created_at']?.toString();
    final dateStr = createdAt != null
        ? '${DateTime.parse(createdAt).day}/${DateTime.parse(createdAt).month}/${DateTime.parse(createdAt).year}'
        : '';
    final customerId = detail['customer_id']?.toString();
    final customerName = customerId != null
        ? customers.where((c) => c.id == customerId).firstOrNull?.name ?? 'Walk-in'
        : 'Walk-in';
    final grand = double.tryParse(detail['grand_total']?.toString() ?? '0') ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(number, style: AppTypography.title2),
          const SizedBox(height: 4),
          Text('$dateStr · $customerName', style: AppTypography.subhead.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text('Total: ${formatPkr(grand)}', style: AppTypography.headline.copyWith(color: AppColors.accent)),
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
    final desc = item['description']?.toString() ?? 'Item';
    final unitPrice = double.tryParse(item['unit_price']?.toString() ?? '0') ?? 0;
    final active = returnQty > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: active ? AppColors.accent.withValues(alpha: 0.04) : AppColors.fieldFill,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: active ? Border.all(color: AppColors.accent.withValues(alpha: 0.3)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(desc, style: AppTypography.subhead),
                const SizedBox(height: 2),
                Text('${formatPkr(unitPrice)}  (max ${maxQty.toStringAsFixed(0)})',
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.remove_circle_outline, color: AppColors.textMuted, size: 22),
                onPressed: returnQty > 0 ? () => onChanged(returnQty - 1) : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              SizedBox(
                width: 30,
                child: Text(
                  returnQty.toStringAsFixed(0),
                  textAlign: TextAlign.center,
                  style: AppTypography.headline.copyWith(color: active ? AppColors.accent : AppColors.textMuted),
                ),
              ),
              IconButton(
                icon: Icon(Icons.add_circle_outline, color: AppColors.accent, size: 22),
                onPressed: returnQty < maxQty ? () => onChanged(returnQty + 1) : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
