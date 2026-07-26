import 'dart:async';
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
import '../../../../core/design/widgets/app_field.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_search_field.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/design/widgets/app_sheet.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../../inventory/domain/entities/product.dart';
import '../../../inventory/domain/usecases/search_products.dart';
import '../../../suppliers/domain/entities/supplier.dart';
import '../../domain/entities/purchase_order.dart';
import '../controllers/purchase_order_detail_provider.dart';
import '../controllers/purchase_orders_controller.dart';
import '../widgets/purchasing_ui.dart';
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
  bool _saveAttempted = false; // drives per-line "product required" highlight
  String? _poNumber; // display-only: loaded PO's number for the header
  PurchaseOrderStatus? _status; // display-only: drives the locked banner label

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
        _poNumber = po.poNumber;
        _status = po.status;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingExisting = false;
        _error = 'Unable to load purchase order. $e';
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
    final product = await showAppSheet<Product>(
      context: context,
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
    setState(() => _saveAttempted = true);
    if (_supplier == null) {
      setState(() => _error = 'Supplier is required.');
      return;
    }
    if (_lines.isEmpty) {
      setState(() => _error = 'Add at least one line.');
      return;
    }
    // Validate every line individually — never silently drop a line the user
    // filled. A line with a total but no product (the common trap) is flagged
    // specifically and its product row is highlighted via _saveAttempted.
    if (_lines.any((l) => l.productId == null)) {
      setState(() => _error = _lines.length == 1
          ? 'Select a product for this line before saving.'
          : 'Select a product for every line, or remove the empty one(s).');
      return;
    }
    if (_lines.any((l) => l._qty <= 0)) {
      setState(() => _error = 'Every line needs a quantity greater than 0.');
      return;
    }
    if (_lines.any((l) => l._cost < 0)) {
      setState(() => _error = 'Unit cost cannot be negative.');
      return;
    }
    final validLines = _lines;
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

  String get _lockedLabel =>
      _status == null ? 'not a draft' : poStatusPill(_status!).$2.toLowerCase();

  @override
  Widget build(BuildContext context) {
    final title =
        _isEditing ? (_locked ? 'View PO' : 'Edit PO') : 'New purchase order';

    return AppDetailScaffold(
      eyebrow: 'Purchasing',
      title: title,
      description: _poNumber ?? 'Draft',
      child: _loadingExisting
          ? const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_locked) ...[
                  AppInlineBanner(
                    message:
                        'This PO is $_lockedLabel and can no longer be edited.',
                    type: BannerType.warning,
                  ),
                  const SizedBox(height: 14),
                ],
                _supplierDatesCard(context),
                const SizedBox(height: 14),
                _lineItemsCard(context),
                const SizedBox(height: 14),
                _extraInfoCard(context),
                const SizedBox(height: 14),
                _totalsCard(context),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  AppInlineBanner(message: _error!, type: BannerType.error),
                ],
                const SizedBox(height: 14),
                AppButton(
                  label: _isEditing ? 'Update PO' : 'Create PO',
                  loading: _saving,
                  fullWidth: true,
                  onPressed: _locked ? null : _save,
                ),
              ],
            ),
    );
  }

  Widget _supplierDatesCard(BuildContext context) {
    return AppSectionCard(
      eyebrow: 'Supplier & dates',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppFieldRow(children: [
            _PickerField(
              label: 'Supplier',
              isRequired: true,
              icon: LucideIcons.truck,
              value: _supplier?.name ?? 'Select supplier',
              placeholder: _supplier == null,
              onTap: _locked ? null : _pickSupplier,
            ),
            _PickerField(
              label: 'Order date',
              isRequired: true,
              icon: LucideIcons.calendar,
              value: _fmtDate(_orderDate),
              placeholder: false,
              onTap: _locked ? null : () => _pickDate(isExpected: false),
            ),
            _labeled(
              context,
              'Currency',
              AppDropdown<String>(
                value: _currency.text.trim().isEmpty ? null : _currency.text,
                options: const [
                  AppDropdownOption(value: 'PKR', label: 'PKR'),
                  AppDropdownOption(value: 'USD', label: 'USD'),
                  AppDropdownOption(value: 'AED', label: 'AED'),
                ],
                onSelected: (v) => setState(() => _currency.text = v),
                enabled: !_locked,
              ),
              isRequired: true,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _lineItemsCard(BuildContext context) {
    return AppSectionCard(
      eyebrow: 'Line items',
      trailing: AppButton(
        label: 'Add line',
        variant: AppButtonVariant.tinted,
        size: AppButtonSize.sm,
        icon: LucideIcons.plus,
        onPressed: _locked ? null : () => _addLine(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in _lines) ...[
            _lineCard(context, line),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _lineCard(BuildContext context, _LineDraft line) {
    final lum = context.lum;
    final missing = line.productId == null;
    final showError = _saveAttempted && missing;

    return ClayContainer(
      variant: ClayVariant.inset,
      color: lum.surface,
      borderRadius: AppRadius.md,
      isDark: lum.isDark,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _locked ? null : () => _pickProduct(line),
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    decoration: BoxDecoration(
                      color: lum.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: showError ? lum.danger : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.boxes,
                            size: 18,
                            color: missing ? lum.accent : lum.g500),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            missing ? 'Select product' : line.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.subhead.copyWith(
                              color:
                                  missing ? lum.accent : lum.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(LucideIcons.chevronRight,
                            size: 18, color: lum.g400),
                      ],
                    ),
                  ),
                ),
              ),
              if (_lines.length > 1) ...[
                const SizedBox(width: 6),
                Semantics(
                  button: true,
                  label: 'Remove line',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _locked ? null : () => _removeLine(line),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(LucideIcons.x, size: 18, color: lum.g500),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (showError) ...[
            const SizedBox(height: 6),
            Text('Product required',
                style:
                    AppTypography.caption.copyWith(color: lum.dangerText)),
          ],
          const SizedBox(height: 12),
          AppFieldRow(
            minFieldWidth: 130,
            children: [
              _lineNumField(line.qtyCtrl, 'Qty', isRequired: true),
              _lineNumField(line.costCtrl, 'Unit cost', isRequired: true),
              _lineNumField(line.taxCtrl, 'Tax %'),
              _lineNumField(line.discountCtrl, 'Disc %'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text('Line total',
                    style: AppTypography.subhead.copyWith(color: lum.g500)),
              ),
              AppMoneyText(line.lineAfterDiscount, size: 16),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lineNumField(TextEditingController c, String label,
          {bool isRequired = false}) =>
      _numField(c, label, LucideIcons.hash, isRequired: isRequired);

  /// Everything optional — dates, rate, landed-cost charges, notes.
  Widget _extraInfoCard(BuildContext context) {
    return AppSectionCard(
      eyebrow: 'Additional details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppFieldRow(children: [
            _PickerField(
              label: 'Expected date',
              icon: LucideIcons.calendar,
              value:
                  _expectedDate != null ? _fmtDate(_expectedDate!) : 'Optional',
              placeholder: _expectedDate == null,
              onTap: _locked ? null : () => _pickDate(isExpected: true),
            ),
            _numField(_exchangeRate, 'Exch. rate', LucideIcons.arrowRightLeft),
          ]),
          const SizedBox(height: 14),
          AppFieldRow(children: [
            _numField(_freight, 'Freight', LucideIcons.truck),
            _numField(_insurance, 'Insurance', LucideIcons.shield),
            _numField(_customDuty, 'Custom duty', LucideIcons.landmark),
          ]),
          const SizedBox(height: 14),
          _numField(_discountTotal, 'Order discount', LucideIcons.percent),
          const SizedBox(height: 14),
          AppTextField(
            controller: _notes,
            label: 'Notes',
            prefixIcon: LucideIcons.messageSquare,
            hint: 'Optional',
            maxLines: 3,
            enabled: !_locked,
          ),
        ],
      ),
    );
  }

  Widget _numField(TextEditingController c, String label, IconData icon,
          {bool isRequired = false}) =>
      AppTextField(
        controller: c,
        label: label,
        prefixIcon: icon,
        isRequired: isRequired,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        enabled: !_locked,
      );

  Widget _totalsCard(BuildContext context) {
    final lum = context.lum;
    return AppSectionCard(
      eyebrow: 'Totals',
      child: Column(
        children: [
          _moneyRow(context, 'Subtotal', _subtotal),
          _moneyRow(context, 'Order discount', -_num(_discountTotal),
              danger: true),
          _moneyRow(context, 'Tax', _taxTotal),
          _moneyRow(context, 'Landed cost', _landedCost),
          Divider(height: 22, color: lum.hairline),
          Row(
            children: [
              Expanded(
                child: Text('Grand total',
                    style: AppTypography.headline
                        .copyWith(color: lum.textPrimary)),
              ),
              AppMoneyText(_grandTotal, size: 22, color: lum.accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _moneyRow(BuildContext context, String k, double v,
      {bool danger = false}) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child:
                Text(k, style: AppTypography.subhead.copyWith(color: lum.g500)),
          ),
          AppMoneyText(v, size: 15, color: danger ? lum.dangerText : null),
        ],
      ),
    );
  }

  Widget _labeled(BuildContext context, String label, Widget child,
      {bool isRequired = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFieldLabel(label, isRequired: isRequired),
        child,
      ],
    );
  }
}

/// A labelled, tappable clay well used for the supplier and date pickers. When
/// [onTap] is null (a locked PO) the well renders non-interactive.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.icon,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.isRequired = false,
  });

  final String label;
  final IconData icon;
  final String value;
  final bool placeholder;
  final VoidCallback? onTap;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFieldLabel(label, isRequired: isRequired),
        Semantics(
          button: true,
          label: '$label: $value',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Opacity(
              opacity: onTap == null ? 0.7 : 1,
              child: ClayContainer(
                variant: ClayVariant.inset,
                color: lum.surface2,
                borderRadius: AppRadius.md,
                isDark: lum.isDark,
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: lum.g400),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.fieldText.copyWith(
                          color:
                              placeholder ? lum.textTertiary : lum.textPrimary,
                        ),
                      ),
                    ),
                    Icon(LucideIcons.chevronRight, size: 18, color: lum.g400),
                  ],
                ),
              ),
            ),
          ),
        ),
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
        // SERVICE products are non-stock — exclude from the PO line picker.
        _results =
            products.where((p) => p.type != ProductType.service).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetHeader(title: 'Select product'),
        AppSearchField(
          controller: _searchCtrl,
          hint: 'Search name or SKU…',
          onSubmitted: _run,
          onClear: () => _run(''),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          AppInlineBanner(message: _error!, type: BannerType.error)
        else if (_results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Text('No products found.',
                textAlign: TextAlign.center,
                style: AppTypography.footnote.copyWith(color: lum.g500)),
          )
        else
          for (final p in _results) ...[
            _ProductTile(
              product: p,
              onTap: () => Navigator.of(context).pop(p),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.onTap});
  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      button: true,
      label: product.name,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: ClayContainer(
            variant: ClayVariant.inset,
            color: lum.surface2,
            borderRadius: AppRadius.md,
            isDark: lum.isDark,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                ClayContainer(
                  variant: ClayVariant.soft,
                  color: lum.accentSoft,
                  borderRadius: AppRadius.sm,
                  isDark: lum.isDark,
                  width: 38,
                  height: 38,
                  child: Center(
                    child: Icon(LucideIcons.package,
                        size: 18, color: lum.accentPress),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: AppTypography.headline
                            .copyWith(color: lum.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text('SKU ${product.sku}',
                          style:
                              AppTypography.caption.copyWith(color: lum.g500)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AppMoneyText(product.costPrice, size: 15),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
