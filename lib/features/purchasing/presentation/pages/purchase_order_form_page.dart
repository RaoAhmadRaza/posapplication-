import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../../inventory/domain/entities/product.dart';
import '../../../inventory/domain/usecases/search_products.dart';
import '../../../suppliers/domain/entities/supplier.dart';
import '../../domain/entities/purchase_order.dart';
import '../controllers/purchase_order_detail_provider.dart';
import '../controllers/purchase_orders_controller.dart';
import 'supplier_picker_sheet.dart';

/// One editable PO line. Holds its own controllers; disposed with the page.
class _LineDraft {
  _LineDraft({
    this.productId,
    this.name = '',
    String qty = '1',
    String cost = '0',
    String tax = '0',
    String discount = '0',
  })  : qtyCtrl = TextEditingController(text: qty),
        costCtrl = TextEditingController(text: cost),
        taxCtrl = TextEditingController(text: tax),
        discountCtrl = TextEditingController(text: discount);

  String? productId;
  String name;
  final TextEditingController qtyCtrl;
  final TextEditingController costCtrl;
  final TextEditingController taxCtrl;
  final TextEditingController discountCtrl;

  double get _qty => double.tryParse(qtyCtrl.text.trim()) ?? 0;
  double get _cost => double.tryParse(costCtrl.text.trim()) ?? 0;
  double get _tax => double.tryParse(taxCtrl.text.trim()) ?? 0;
  double get _discount => double.tryParse(discountCtrl.text.trim()) ?? 0;

  double get lineBase => _qty * _cost;
  double get lineAfterDiscount => lineBase * (1 - _discount / 100);
  double get lineTax => lineAfterDiscount * _tax / 100;

  void dispose() {
    qtyCtrl.dispose();
    costCtrl.dispose();
    taxCtrl.dispose();
    discountCtrl.dispose();
  }
}

class PurchaseOrderFormPage extends ConsumerStatefulWidget {
  const PurchaseOrderFormPage({super.key, this.poId, this.initialLines});

  final String? poId;
  final List<({String productId, String name, double unitCost})>? initialLines;

  @override
  ConsumerState<PurchaseOrderFormPage> createState() =>
      _PurchaseOrderFormPageState();
}

class _PurchaseOrderFormPageState
    extends ConsumerState<PurchaseOrderFormPage> {
  final _currency = TextEditingController(text: 'PKR');
  final _exchangeRate = TextEditingController(text: '1.0');
  final _freight = TextEditingController(text: '0');
  final _insurance = TextEditingController(text: '0');
  final _customDuty = TextEditingController(text: '0');
  final _discountTotal = TextEditingController(text: '0');
  final _notes = TextEditingController();

  final List<_LineDraft> _lines = [];
  Supplier? _supplier;
  DateTime _orderDate = DateTime.now();
  DateTime? _expectedDate;

  String? _error;
  bool _saving = false;
  bool _loadingExisting = false;
  bool _locked = false; // edit blocked when PO is not draft

  bool get _isEditing => widget.poId != null;

  @override
  void initState() {
    super.initState();
    for (final c in [
      _freight,
      _insurance,
      _customDuty,
      _discountTotal,
    ]) {
      c.addListener(_onTotalsChanged);
    }
    if (_isEditing) {
      _loadExisting();
    } else {
      _seedInitialLines();
    }
  }

  @override
  void dispose() {
    for (final c in [
      _currency,
      _exchangeRate,
      _freight,
      _insurance,
      _customDuty,
      _discountTotal,
      _notes,
    ]) {
      c.dispose();
    }
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _onTotalsChanged() {
    if (mounted) setState(() {});
  }

  void _seedInitialLines() {
    final seeds = widget.initialLines;
    if (seeds == null || seeds.isEmpty) {
      _addLine();
      return;
    }
    for (final s in seeds) {
      _addLine(
        productId: s.productId,
        name: s.name,
        cost: s.unitCost.toString(),
      );
    }
  }

  Future<void> _loadExisting() async {
    setState(() => _loadingExisting = true);
    try {
      final data =
          await ref.read(purchaseOrderDetailProvider(widget.poId!).future);
      if (!mounted) return;
      final po = data.po;
      _supplierFromId(po.supplierId);
      _currency.text = po.currency;
      _exchangeRate.text = po.exchangeRate.toString();
      _freight.text = po.freightCharges.toString();
      _insurance.text = po.insuranceCharges.toString();
      _customDuty.text = po.customDuty.toString();
      _discountTotal.text = po.discountTotal.toString();
      _notes.text = po.notes ?? '';
      _orderDate = po.orderDate;
      _expectedDate = po.expectedDate;
      for (final it in data.items) {
        _addLine(
          productId: it.productId,
          name: 'Item ${it.productId.substring(0, 6)}',
          qty: it.qtyOrdered.toString(),
          cost: it.unitCost.toString(),
          tax: it.taxPct.toString(),
          discount: it.discountPct.toString(),
        );
      }
      setState(() {
        _loadingExisting = false;
        _locked = po.status != PurchaseOrderStatus.draft;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingExisting = false;
        _error = 'Could not load purchase order. $e';
      });
    }
  }

  /// Best-effort: fill supplier chip from the loaded PO's supplier id. The
  /// suppliers list may not contain it; the id still ships on save via _supplier.
  void _supplierFromId(String id) {
    _supplier = Supplier(
      id: id,
      tenantId: '',
      name: 'Supplier ${id.substring(0, 6)}',
      paymentTerms: 0,
      currency: 'PKR',
      openingBalance: 0,
      status: SupplierStatus.active,
      createdAt: DateTime.now(),
    );
  }

  void _addLine({
    String? productId,
    String name = '',
    String qty = '1',
    String cost = '0',
    String tax = '0',
    String discount = '0',
  }) {
    final line = _LineDraft(
      productId: productId,
      name: name,
      qty: qty,
      cost: cost,
      tax: tax,
      discount: discount,
    );
    for (final c in [
      line.qtyCtrl,
      line.costCtrl,
      line.taxCtrl,
      line.discountCtrl,
    ]) {
      c.addListener(_onTotalsChanged);
    }
    setState(() => _lines.add(line));
  }

  void _removeLine(_LineDraft line) {
    setState(() => _lines.remove(line));
    line.dispose();
  }

  Future<void> _pickSupplier() async {
    final chosen = await showSupplierPicker(context);
    if (chosen != null && mounted) setState(() => _supplier = chosen);
  }

  Future<void> _pickProduct(_LineDraft line) async {
    final product = await showModalBottomSheet<Product?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (_) => const _ProductPickerSheet(),
    );
    if (product == null || !mounted) return;
    setState(() {
      line.productId = product.id;
      line.name = product.name;
      line.costCtrl.text = product.costPrice.toString();
    });
  }

  Future<void> _pickDate({required bool isExpected}) async {
    final initial = isExpected ? (_expectedDate ?? _orderDate) : _orderDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isExpected) {
        _expectedDate = picked;
      } else {
        _orderDate = picked;
      }
    });
  }

  double get _subtotal =>
      _lines.fold(0, (sum, l) => sum + l.lineAfterDiscount);
  double get _taxTotal => _lines.fold(0, (sum, l) => sum + l.lineTax);
  double get _landedCost =>
      _num(_freight) + _num(_insurance) + _num(_customDuty);
  double get _grandTotal =>
      _subtotal - _num(_discountTotal) + _taxTotal + _landedCost;

  double _num(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  Future<void> _save() async {
    if (_locked) return;
    if (_supplier == null) {
      setState(() => _error = 'Supplier is required.');
      return;
    }
    final validLines = _lines
        .where((l) => l.productId != null && l._qty > 0 && l._cost >= 0)
        .toList();
    if (validLines.isEmpty) {
      setState(() => _error =
          'Add at least one line with a product, quantity > 0 and cost ≥ 0.');
      return;
    }
    final currency = _currency.text.trim();
    if (currency.isEmpty) {
      setState(() => _error = 'Currency is required.');
      return;
    }

    String? branchId;
    if (!_isEditing) {
      final branch = ref.read(currentBranchProvider);
      if (branch == null) {
        setState(() => _error = 'No branch selected.');
        return;
      }
      branchId = branch.id;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final items = validLines
        .map((l) => {
              'product_id': l.productId,
              'qty_ordered': l._qty,
              'unit_cost': l._cost,
              'tax_pct': l._tax,
              'discount_pct': l._discount,
            })
        .toList();

    final data = <String, dynamic>{
      if (!_isEditing) 'p_branch_id': branchId,
      'p_supplier_id': _supplier!.id,
      'p_order_date': _fmtDate(_orderDate),
      'p_expected_date':
          _expectedDate != null ? _fmtDate(_expectedDate!) : null,
      'p_currency': currency,
      'p_exchange_rate': double.tryParse(_exchangeRate.text.trim()) ?? 1.0,
      'p_freight': _num(_freight),
      'p_insurance': _num(_insurance),
      'p_custom_duty': _num(_customDuty),
      'p_discount_total': _num(_discountTotal),
      'p_notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      'p_items': items,
    };

    final notifier = ref.read(purchaseOrdersProvider.notifier);
    final failure = _isEditing
        ? await notifier.edit(widget.poId!, data)
        : await notifier.create(data);

    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _saving = false;
        _error = failure.message;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  String _fmtDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
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
        title: Text(_isEditing ? 'Edit PO' : 'New PO',
            style: AppTypography.headline),
      ),
      body: _loadingExisting
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, _) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPadding),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AppSpacing.lg),
                          if (_locked) ...[
                            AppInlineBanner(
                                message:
                                    'This PO is no longer a draft and cannot be edited.',
                                type: BannerType.info),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          if (_error != null) ...[
                            AppInlineBanner(
                                message: _error!, type: BannerType.error),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          _group('Supplier'),
                          _SupplierField(
                            supplier: _supplier,
                            onTap: _locked ? null : _pickSupplier,
                          ),
                          _sectionGap(),
                          _group('Dates'),
                          _DateField(
                            label: 'Order Date',
                            value: _fmtDate(_orderDate),
                            onTap:
                                _locked ? null : () => _pickDate(isExpected: false),
                          ),
                          _gap(),
                          _DateField(
                            label: 'Expected Date',
                            value: _expectedDate != null
                                ? _fmtDate(_expectedDate!)
                                : 'Optional',
                            onTap:
                                _locked ? null : () => _pickDate(isExpected: true),
                          ),
                          _sectionGap(),
                          _group('Currency'),
                          AppTextField(
                              controller: _currency,
                              label: 'Currency',
                              prefixIcon: Icons.attach_money),
                          _gap(),
                          AppTextField(
                              controller: _exchangeRate,
                              label: 'Exchange Rate',
                              prefixIcon: Icons.currency_exchange,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true)),
                          _sectionGap(),
                          _group('Items'),
                          for (final line in _lines)
                            _LineEditor(
                              line: line,
                              enabled: !_locked,
                              onPickProduct: () => _pickProduct(line),
                              onRemove:
                                  _lines.length > 1 ? () => _removeLine(line) : null,
                            ),
                          const SizedBox(height: AppSpacing.sm),
                          AppButton(
                            label: '+ Add line',
                            variant: AppButtonVariant.plain,
                            icon: Icons.add,
                            onPressed: _locked ? null : () => _addLine(),
                          ),
                          _sectionGap(),
                          _group('Charges'),
                          AppTextField(
                              controller: _freight,
                              label: 'Freight',
                              prefixIcon: Icons.local_shipping,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true)),
                          _gap(),
                          AppTextField(
                              controller: _insurance,
                              label: 'Insurance',
                              prefixIcon: Icons.shield_outlined,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true)),
                          _gap(),
                          AppTextField(
                              controller: _customDuty,
                              label: 'Custom Duty',
                              prefixIcon: Icons.account_balance,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true)),
                          _gap(),
                          AppTextField(
                              controller: _discountTotal,
                              label: 'Order Discount',
                              prefixIcon: Icons.percent,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true)),
                          _sectionGap(),
                          _group('Notes'),
                          AppTextField(
                              controller: _notes,
                              label: 'Notes',
                              prefixIcon: Icons.notes,
                              hint: 'Optional'),
                          _sectionGap(),
                          _TotalsPanel(
                            subtotal: _subtotal,
                            tax: _taxTotal,
                            landedCost: _landedCost,
                            grandTotal: _grandTotal,
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          AppButton(
                            label: _isEditing ? 'Update PO' : 'Create PO',
                            loading: _saving,
                            fullWidth: true,
                            onPressed: _locked ? null : _save,
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

class _SupplierField extends StatelessWidget {
  const _SupplierField({required this.supplier, required this.onTap});
  final Supplier? supplier;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_shipping,
                size: 18, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                supplier?.name ?? 'Select supplier',
                style: AppTypography.body.copyWith(
                    color: supplier == null
                        ? AppColors.textHint
                        : AppColors.textPrimary),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.separator),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField(
      {required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                size: 16, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.md),
            Expanded(
                child: Text(label,
                    style: AppTypography.body
                        .copyWith(color: AppColors.textPrimary))),
            Text(value,
                style: AppTypography.footnote
                    .copyWith(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _LineEditor extends StatelessWidget {
  const _LineEditor({
    required this.line,
    required this.enabled,
    required this.onPickProduct,
    required this.onRemove,
  });

  final _LineDraft line;
  final bool enabled;
  final VoidCallback onPickProduct;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: enabled ? onPickProduct : null,
                      child: Text(
                        line.productId == null
                            ? 'Select product'
                            : line.name,
                        style: AppTypography.subhead.copyWith(
                          color: line.productId == null
                              ? AppColors.accent
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (onRemove != null)
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 18, color: AppColors.textMuted),
                      onPressed: enabled ? onRemove : null,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(child: _numField(line.qtyCtrl, 'Qty')),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _numField(line.costCtrl, 'Unit Cost')),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(child: _numField(line.taxCtrl, 'Tax %')),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _numField(line.discountCtrl, 'Disc %')),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: Text('Line: ${formatPkr(line.lineAfterDiscount)}',
                    style: AppTypography.footnote.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      enabled: enabled,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      style: AppTypography.fieldText,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.fieldLabel,
        filled: true,
        fillColor: AppColors.fieldFill,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _TotalsPanel extends StatelessWidget {
  const _TotalsPanel({
    required this.subtotal,
    required this.tax,
    required this.landedCost,
    required this.grandTotal,
  });

  final double subtotal;
  final double tax;
  final double landedCost;
  final double grandTotal;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            _row('Subtotal', subtotal),
            const SizedBox(height: AppSpacing.sm),
            _row('Tax', tax),
            const SizedBox(height: AppSpacing.sm),
            _row('Landed Cost', landedCost),
            const Divider(color: AppColors.separator, height: AppSpacing.xl),
            _row('Grand Total', grandTotal, emphasize: true),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, double value, {bool emphasize = false}) {
    final style = emphasize
        ? AppTypography.headline
        : AppTypography.footnote.copyWith(color: AppColors.textMuted);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(formatPkr(value), style: style),
      ],
    );
  }
}

/// Inline product search sheet returning the chosen [Product].
class _ProductPickerSheet extends ConsumerStatefulWidget {
  const _ProductPickerSheet();

  @override
  ConsumerState<_ProductPickerSheet> createState() =>
      _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<_ProductPickerSheet> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<Product> _results = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => _onChanged(_searchCtrl.text));
    _run('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(q));
  }

  Future<void> _run(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final (products, failure) =
        await ref.read(searchProductsUseCaseProvider).call(q.trim());
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (failure != null) {
        _error = failure.message;
      } else {
        _results = products;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.screenPadding,
          right: AppSpacing.screenPadding,
          top: AppSpacing.md,
          bottom: AppSpacing.md + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.separator,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Select Product', style: AppTypography.title2),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _searchCtrl,
              label: 'Search',
              prefixIcon: Icons.search,
              hint: 'Name or SKU',
              onSubmitted: _run,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              AppInlineBanner(message: _error!, type: BannerType.error)
            else if (_results.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Text('No products found.',
                    style: AppTypography.footnote
                        .copyWith(color: AppColors.textHint)),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final p = _results[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.name, style: AppTypography.headline),
                      subtitle: Text('SKU ${p.sku} · ${formatPkr(p.costPrice)}',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMuted)),
                      onTap: () => Navigator.of(context).pop(p),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
