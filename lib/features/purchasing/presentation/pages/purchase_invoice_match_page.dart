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
import '../../../inventory/domain/entities/product.dart';
import '../../../inventory/domain/usecases/get_product.dart';
import '../../domain/entities/grn.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/entities/purchase_order_item.dart';
import '../../domain/entities/purchase_results.dart';
import '../controllers/purchase_invoices_controller.dart';
import '../controllers/purchase_order_detail_provider.dart';

/// 3-way match: PO ordered/received vs supplier invoice entry.
class PurchaseInvoiceMatchPage extends ConsumerStatefulWidget {
  const PurchaseInvoiceMatchPage({super.key, required this.poId});

  final String poId;

  @override
  ConsumerState<PurchaseInvoiceMatchPage> createState() =>
      _PurchaseInvoiceMatchPageState();
}

class _PurchaseInvoiceMatchPageState
    extends ConsumerState<PurchaseInvoiceMatchPage> {
  final _invoiceNumber = TextEditingController();
  final _amount = TextEditingController();
  final _tax = TextEditingController();
  final _notes = TextEditingController();

  final Map<String, Product> _products = {};
  DateTime? _dueDate;
  String? _grnId;
  bool _seeded = false;
  bool _initializing = false;
  bool _submitting = false;
  String? _error;
  InvoiceCreateResult? _result;

  @override
  void dispose() {
    _invoiceNumber.dispose();
    _amount.dispose();
    _tax.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _ensureInit(
      PurchaseOrder po, List<PurchaseOrderItem> items) async {
    if (_seeded || _initializing) return;
    _initializing = true;
    _amount.text = po.subtotal.toStringAsFixed(2);
    _tax.text = po.taxTotal.toStringAsFixed(2);
    for (final id in items.map((i) => i.productId).toSet()) {
      final (product, _) = await ref.read(getProductUseCaseProvider).call(id);
      if (product != null) _products[id] = product;
    }
    if (!mounted) return;
    setState(() {
      _seeded = true;
      _initializing = false;
    });
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _create() async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Amount must be a positive number.');
      return;
    }
    final tax = double.tryParse(_tax.text.trim());
    if (tax == null || tax < 0) {
      setState(() => _error = 'Tax amount must be zero or greater.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final (result, failure) =
        await ref.read(purchaseInvoicesProvider.notifier).create(
              poId: widget.poId,
              grnId: _grnId,
              supplierInvoiceNumber: _clean(_invoiceNumber),
              amount: amount,
              taxAmount: tax,
              dueDate: _dueDate,
              notes: _clean(_notes),
            );

    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _submitting = false;
        _error = failure.message;
      });
      return;
    }
    setState(() {
      _submitting = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(purchaseOrderDetailProvider(widget.poId));

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
        title: Text('Match Invoice', style: AppTypography.headline),
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            child: AppInlineBanner(
                message: 'Could not load purchase order.',
                type: BannerType.error),
          ),
        ),
        data: (data) {
          _ensureInit(data.po, data.items);
          if (!_seeded) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_result != null) {
            return _ResultView(
              result: _result!,
              onDone: () => Navigator.of(context).pop(),
            );
          }
          return _buildForm(context, data.po, data.items);
        },
      ),
    );
  }

  Widget _buildForm(
      BuildContext context, PurchaseOrder po, List<PurchaseOrderItem> items) {
    final grnsAsync = ref.watch(poGrnsProvider(widget.poId));

    final left = _PoSummaryColumn(
      po: po,
      items: items,
      products: _products,
    );
    final right = _InvoiceFormColumn(
      invoiceNumber: _invoiceNumber,
      amount: _amount,
      tax: _tax,
      notes: _notes,
      dueDate: _dueDate,
      onPickDueDate: _pickDueDate,
      onClearDueDate: () => setState(() => _dueDate = null),
      grnsAsync: grnsAsync,
      grnId: _grnId,
      onGrnChanged: (v) => setState(() => _grnId = v),
      error: _error,
      submitting: _submitting,
      onSubmit: _create,
    );

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 760;
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
                vertical: AppSpacing.md),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: left),
                      const SizedBox(width: AppSpacing.xl),
                      Expanded(child: right),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      left,
                      const SizedBox(height: AppSpacing.xl),
                      right,
                    ],
                  ),
          );
        },
      ),
    );
  }

  String? _clean(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }
}

class _PoSummaryColumn extends StatelessWidget {
  const _PoSummaryColumn(
      {required this.po, required this.items, required this.products});

  final PurchaseOrder po;
  final List<PurchaseOrderItem> items;
  final Map<String, Product> products;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PO ${po.poNumber}', style: AppTypography.headline),
            Text('Ordered vs received',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textMuted)),
            const Divider(color: AppColors.separator, height: AppSpacing.xl),
            for (final line in items) ...[
              Text(products[line.productId]?.name ?? line.productId,
                  style: AppTypography.footnote,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ord ${_fmtQty(line.qtyOrdered)}  ·  Rcv ${_fmtQty(line.qtyReceived)}',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                  Text(formatPkr(line.lineTotal),
                      style: AppTypography.caption),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            const Divider(color: AppColors.separator, height: AppSpacing.sm),
            const SizedBox(height: AppSpacing.sm),
            _totalRow('Subtotal', po.subtotal),
            _totalRow('Tax', po.taxTotal),
            _totalRow('Grand total', po.grandTotal, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: bold
                    ? AppTypography.footnote
                        .copyWith(fontWeight: FontWeight.w600)
                    : AppTypography.footnote
                        .copyWith(color: AppColors.textMuted)),
            Text(formatPkr(value),
                style: bold
                    ? AppTypography.footnote
                        .copyWith(fontWeight: FontWeight.w600)
                    : AppTypography.footnote),
          ],
        ),
      );

  String _fmtQty(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _InvoiceFormColumn extends StatelessWidget {
  const _InvoiceFormColumn({
    required this.invoiceNumber,
    required this.amount,
    required this.tax,
    required this.notes,
    required this.dueDate,
    required this.onPickDueDate,
    required this.onClearDueDate,
    required this.grnsAsync,
    required this.grnId,
    required this.onGrnChanged,
    required this.error,
    required this.submitting,
    required this.onSubmit,
  });

  final TextEditingController invoiceNumber;
  final TextEditingController amount;
  final TextEditingController tax;
  final TextEditingController notes;
  final DateTime? dueDate;
  final VoidCallback onPickDueDate;
  final VoidCallback onClearDueDate;
  final AsyncValue<List<Grn>> grnsAsync;
  final String? grnId;
  final ValueChanged<String?> onGrnChanged;
  final String? error;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          AppInlineBanner(message: error!, type: BannerType.error),
          const SizedBox(height: AppSpacing.md),
        ],
        AppTextField(
          controller: invoiceNumber,
          label: 'Supplier Invoice Number',
          prefixIcon: Icons.receipt_long,
          hint: 'Optional',
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: amount,
          label: 'Amount',
          prefixIcon: Icons.payments,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: tax,
          label: 'Tax Amount',
          prefixIcon: Icons.percent,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: AppSpacing.md),
        InkWell(
          onTap: onPickDueDate,
          borderRadius: BorderRadius.circular(AppRadius.field),
          child: Row(
            children: [
              const Icon(Icons.event, size: 18, color: AppColors.textMuted),
              const SizedBox(width: AppSpacing.sm),
              Text(
                dueDate != null
                    ? 'Due: ${_fmtDate(dueDate!)}'
                    : 'Set due date (optional)',
                style: AppTypography.footnote,
              ),
              if (dueDate != null) ...[
                const SizedBox(width: AppSpacing.sm),
                GestureDetector(
                  onTap: onClearDueDate,
                  child: const Icon(Icons.close,
                      size: 16, color: AppColors.textHint),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _grnDropdown(),
        const SizedBox(height: AppSpacing.xl),
        PermissionGate(
          module: 'purchase',
          action: 'create',
          child: AppButton(
            label: 'Create Invoice',
            loading: submitting,
            fullWidth: true,
            onPressed: onSubmit,
          ),
        ),
      ],
    );
  }

  Widget _grnDropdown() {
    return grnsAsync.when(
      loading: () => const SizedBox(
        height: 32,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => AppInlineBanner(
          message: 'Could not load GRNs.', type: BannerType.info),
      data: (grns) {
        if (grns.isEmpty) {
          return Text('No GRNs recorded yet.',
              style:
                  AppTypography.caption.copyWith(color: AppColors.textHint));
        }
        return DropdownButtonFormField<String?>(
          initialValue: grnId,
          decoration: const InputDecoration(
            labelText: 'Link GRN (optional)',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String?>(
                value: null, child: Text('None')),
            for (final grn in grns)
              DropdownMenuItem<String?>(
                  value: grn.id, child: Text(grn.grnNumber)),
          ],
          onChanged: onGrnChanged,
        );
      },
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result, required this.onDone});

  final InvoiceCreateResult result;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final hasVariance = result.matchVariance != 0;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  hasVariance ? Icons.error_outline : Icons.check_circle,
                  size: 48,
                  color: hasVariance
                      ? AppColors.destructive
                      : AppColors.success,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (hasVariance)
                  Text(
                    'Match variance: ${formatPkr(result.matchVariance)}',
                    textAlign: TextAlign.center,
                    style: AppTypography.headline
                        .copyWith(color: AppColors.destructive),
                  )
                else
                  AppInlineBanner(
                      message: 'Matched — no variance',
                      type: BannerType.success),
                const SizedBox(height: AppSpacing.sm),
                Text('Invoice total: ${formatPkr(result.totalAmount)}',
                    textAlign: TextAlign.center,
                    style: AppTypography.footnote
                        .copyWith(color: AppColors.textMuted)),
                const SizedBox(height: AppSpacing.xxl),
                AppButton(label: 'Done', fullWidth: true, onPressed: onDone),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
