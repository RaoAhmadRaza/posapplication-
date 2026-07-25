import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_confirm_dialog.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_dropdown.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/design/widgets/app_sheet.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/design/widgets/app_toggle.dart';
import '../../../../core/widgets/barcode_scan_page.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../../core/services/scanner_support.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/brand.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_variant.dart';
import '../../domain/entities/product_image.dart';
import '../../domain/entities/pricing_tier.dart';
import '../../domain/failures/inventory_failure.dart';
import '../controllers/categories_controller.dart';
import '../controllers/brands_controller.dart';
import '../controllers/product_edit_controller.dart';
import '../controllers/products_controller.dart';
import '../../../accounting/domain/usecases/resolve_tax_rate.dart';

class ProductFormPage extends ConsumerStatefulWidget {
  const ProductFormPage({super.key, this.productId});
  final String? productId;

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final _nameCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(text: 'PCS');
  final _costPriceCtrl = TextEditingController();
  final _sellingPriceCtrl = TextEditingController();
  final _minPriceCtrl = TextEditingController();
  final _wholesalePriceCtrl = TextEditingController();
  final _taxRateCtrl = TextEditingController();
  final _reorderPointCtrl = TextEditingController();
  final _reorderQtyCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  String _type = 'STANDARD';
  String _status = 'ACTIVE';
  String? _categoryId;
  String? _brandId;
  bool _taxInclusive = false;
  bool _isActive = true;

  String? _error;
  bool _saving = false;
  bool _didSeed = false;
  bool _hasSavedOnce = false;
  bool _uploadingImage = false;

  bool get _isEditing => widget.productId != null;
  bool get _subSectionsEnabled => _isEditing || _hasSavedOnce;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      Future.microtask(() {
        ref.read(productEditProvider.notifier).loadForEdit(widget.productId!);
      });
    } else {
      // New product: default the tax rate from the tenant's default tax_rule
      // (resolve_tax_rate) instead of a hardcoded value — user can still override.
      Future.microtask(() async {
        final (resolved, _) = await ref.read(resolveTaxRateUseCaseProvider)();
        if (!mounted || resolved == null || _taxRateCtrl.text.isNotEmpty) return;
        _taxRateCtrl.text = resolved.rate.toString();
      });
    }
  }

  void _loadExisting(Product p) {
    _nameCtrl.text = p.name;
    _barcodeCtrl.text = p.barcode ?? '';
    _descriptionCtrl.text = p.description ?? '';
    _unitCtrl.text = p.unitOfMeasure;
    _costPriceCtrl.text = p.costPrice.toString();
    _sellingPriceCtrl.text = p.sellingPrice.toString();
    _minPriceCtrl.text = p.minSellingPrice?.toString() ?? '';
    _wholesalePriceCtrl.text = p.wholesalePrice?.toString() ?? '';
    _taxRateCtrl.text = p.taxRate.toString();
    _taxInclusive = p.taxInclusive;
    _reorderPointCtrl.text = p.reorderPoint.toString();
    _reorderQtyCtrl.text = p.reorderQty.toString();
    _weightCtrl.text = p.weight?.toString() ?? '';
    _tagsCtrl.text = p.tags?.join(', ') ?? '';
    _type = _productTypeToString(p.type);
    _status = _productStatusToString(p.status);
    _categoryId = p.categoryId;
    _brandId = p.brandId;
    _isActive = p.isActive;
    _hasSavedOnce = true;
    setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _descriptionCtrl.dispose();
    _unitCtrl.dispose();
    _costPriceCtrl.dispose();
    _sellingPriceCtrl.dispose();
    _minPriceCtrl.dispose();
    _wholesalePriceCtrl.dispose();
    _taxRateCtrl.dispose();
    _reorderPointCtrl.dispose();
    _reorderQtyCtrl.dispose();
    _weightCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildCoreData() {
    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    return {
      'name': _nameCtrl.text.trim(),
      'barcode': _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
      'description': _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
      'type': _type,
      'category_id': _categoryId,
      'brand_id': _brandId,
      'unit_of_measure': _unitCtrl.text.trim().isEmpty ? 'PCS' : _unitCtrl.text.trim(),
      'cost_price': double.tryParse(_costPriceCtrl.text) ?? 0,
      'selling_price': double.tryParse(_sellingPriceCtrl.text) ?? 0,
      'min_selling_price': _minPriceCtrl.text.isEmpty ? null : double.tryParse(_minPriceCtrl.text),
      'wholesale_price': _wholesalePriceCtrl.text.isEmpty ? null : double.tryParse(_wholesalePriceCtrl.text),
      'tax_rate': double.tryParse(_taxRateCtrl.text) ?? 0,
      'tax_inclusive': _taxInclusive,
      'reorder_point': int.tryParse(_reorderPointCtrl.text) ?? 0,
      'reorder_qty': int.tryParse(_reorderQtyCtrl.text) ?? 0,
      'weight': _weightCtrl.text.isEmpty ? null : double.tryParse(_weightCtrl.text),
      'is_active': _isActive,
      'status': _status,
      'tags': tags.isEmpty ? null : tags,
    };
  }

  Future<void> _saveCore() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { setState(() => _error = 'Name is required.'); return; }

    setState(() { _saving = true; _error = null; });

    final failure = await ref.read(productEditProvider.notifier).saveProduct(_buildCoreData());
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _saving = false;
        _error = failure is DuplicateSkuFailure
            ? 'A product with this SKU or barcode already exists.'
            : failure.message;
      });
      return;
    }

    setState(() { _saving = false; _hasSavedOnce = true; });
    ref.invalidate(productsProvider);
    if (!_isEditing) {
      showAppToast(context,
          'Product saved. You can now add variants, images and pricing.');
    }
  }

  Future<void> _saveAndClose() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      await _saveCore();
      return;
    }

    setState(() { _saving = true; _error = null; });

    final failure = await ref.read(productEditProvider.notifier).saveProduct(_buildCoreData());
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _saving = false;
        _error = failure is DuplicateSkuFailure
            ? 'A product with this SKU or barcode already exists.'
            : failure.message;
      });
      return;
    }

    ref.invalidate(productsProvider);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _scanBarcode() async {
    final code = await scanBarcode(context, title: 'Scan Barcode');
    if (code == null || code == BarcodeScanPage.manualEntrySentinel) return;
    _barcodeCtrl.text = code;
    setState(() {});
  }

  Future<void> _confirmDelete() async {
    final ok = await showAppConfirm(
      context,
      title: 'Delete product',
      message: 'Delete this product? It will be soft-deleted.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(productEditProvider.notifier).deleteProduct();
    ref.invalidate(productsProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    ref.listen<AsyncValue<Product?>>(productEditProvider, (prev, next) {
      final p = next.value;
      if (p != null && !_didSeed) {
        _didSeed = true;
        _loadExisting(p);
      }
    });

    final editState = ref.watch(productEditProvider);
    final variants = editState.value != null ? ref.read(productEditProvider.notifier).variantsState.variants : <ProductVariant>[];
    final images = editState.value != null ? ref.read(productEditProvider.notifier).imagesState.images : <ProductImage>[];
    final tiers = editState.value != null ? ref.read(productEditProvider.notifier).pricingState.tiers : <PricingTier>[];

    if (_isEditing) {
      if (editState.isLoading) {
        return Scaffold(
          backgroundColor: lum.paper,
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      if (editState.hasError) {
        return Scaffold(
          backgroundColor: lum.paper,
          body: const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: AppErrorState(
                title: "We couldn't load the product",
                body: 'Please go back and try again.',
              ),
            ),
          ),
        );
      }
    }

    return AppDetailScaffold(
      eyebrow: 'Inventory',
      title: _isEditing ? 'Edit product' : 'New product',
      actions: [
        if (_isEditing)
          PermissionGate(
            module: 'inventory',
            action: 'delete',
            child: AppButton(
              label: 'Delete',
              icon: LucideIcons.trash2,
              variant: AppButtonVariant.destructive,
              size: AppButtonSize.sm,
              onPressed: _confirmDelete,
            ),
          ),
      ],
      bottomBar: _stickyBar(lum),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AppInlineBanner(message: _error!, type: BannerType.error),
            const SizedBox(height: 16),
          ],
          _summaryHeader(lum, images),
          const SizedBox(height: 16),
          AppSectionCard(eyebrow: 'Basic info', child: _buildBasicSection()),
          const SizedBox(height: 14),
          AppSectionCard(eyebrow: 'Pricing', child: _buildPriceInputs()),
          const SizedBox(height: 14),
          AppSectionCard(eyebrow: 'Inventory', child: _buildInventorySection()),
          if (!_subSectionsEnabled) ...[
            const SizedBox(height: 12),
            _saveHint(lum),
          ],
          if (_subSectionsEnabled) ...[
            const SizedBox(height: 22),
            _buildVariantsSection(variants),
            const SizedBox(height: 14),
            _buildImagesSection(images),
            const SizedBox(height: 14),
            _buildPricingSection(tiers),
          ],
        ],
      ),
    );
  }

  // Compact identity header: thumbnail, live name, and a one-line summary so the
  // user always knows what they're editing without scrolling.
  Widget _summaryHeader(LumColors lum, List<ProductImage> images) {
    final name = _nameCtrl.text.trim();
    ProductImage? primary;
    for (final i in images) {
      if (i.isPrimary) { primary = i; break; }
    }
    primary ??= images.isNotEmpty ? images.first : null;
    final barcodeStatus =
        _barcodeCtrl.text.trim().isEmpty ? 'No barcode' : 'Barcode set';
    final summary = '${_typeLabel(_type)} · $barcodeStatus';

    return ClayContainer(
      variant: ClayVariant.soft,
      color: lum.surface,
      borderRadius: AppRadius.lg,
      isDark: lum.isDark,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              width: 52,
              height: 52,
              child: primary != null
                  ? Image.network(primary.url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _thumbFallback(lum))
                  : _thumbFallback(lum),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name.isEmpty ? 'Untitled product' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headline.copyWith(
                      color: name.isEmpty ? lum.g500 : lum.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.footnote.copyWith(color: lum.g500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbFallback(LumColors lum) => Container(
        color: lum.surface2,
        alignment: Alignment.center,
        child: Icon(Icons.inventory_2_outlined, size: 22, color: lum.g400),
      );

  Widget _saveHint(LumColors lum) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: lum.accentSoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.info, size: 16, color: lum.accentPress),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Save the product to add variants, images and pricing tiers.',
                style: AppTypography.footnote.copyWith(color: lum.accentPress),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Basic info ----
  Widget _buildBasicSection() {
    final lum = context.lum;
    final categoriesAsync = ref.watch(categoriesProvider);
    final brandsAsync = ref.watch(brandsProvider);
    final categories = categoriesAsync.value ?? <Category>[];
    final brands = brandsAsync.value ?? <Brand>[];
    final catsLoading = categoriesAsync.isLoading && categories.isEmpty;
    final brandsLoading = brandsAsync.isLoading && brands.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _twoCol(
          AppTextField(
              controller: _nameCtrl,
              label: 'Name',
              prefixIcon: Icons.inventory_2_outlined,
              hint: 'Product name',
              onChanged: (_) => setState(() {})),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AppTextField(
                    controller: _barcodeCtrl,
                    label: 'Barcode',
                    prefixIcon: Icons.qr_code,
                    hint: 'Optional',
                    onChanged: (_) => setState(() {})),
              ),
              if (barcodeScanSupported) ...[
                const SizedBox(width: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _scanButton(lum),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.fieldGap),
        AppTextField(controller: _descriptionCtrl, label: 'Description', prefixIcon: Icons.notes, hint: 'Optional', maxLines: 3),
        const SizedBox(height: AppSpacing.fieldGap),
        _fieldLabel('Type'),
        AppDropdown<String>(
          value: _type,
          options: const [
            AppDropdownOption(value: 'STANDARD', label: 'Standard'),
            AppDropdownOption(value: 'SERIALIZED', label: 'Serialized'),
            AppDropdownOption(value: 'SERVICE', label: 'Service'),
            AppDropdownOption(value: 'COMPOSITE', label: 'Composite'),
          ],
          onSelected: (v) => setState(() => _type = v),
        ),
        const SizedBox(height: AppSpacing.fieldGap),
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _fieldLabel('Category'),
                AppDropdown<String?>(
                  value: _categoryId,
                  placeholder: catsLoading ? 'Loading…' : 'None',
                  enabled: !catsLoading,
                  options: [
                    const AppDropdownOption<String?>(value: null, label: 'None'),
                    for (final c in categories)
                      AppDropdownOption<String?>(value: c.id, label: c.name),
                  ],
                  onSelected: (v) => setState(() => _categoryId = v),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _fieldLabel('Brand'),
                AppDropdown<String?>(
                  value: _brandId,
                  placeholder: brandsLoading ? 'Loading…' : 'None',
                  enabled: !brandsLoading,
                  options: [
                    const AppDropdownOption<String?>(value: null, label: 'None'),
                    for (final b in brands)
                      AppDropdownOption<String?>(value: b.id, label: b.name),
                  ],
                  onSelected: (v) => setState(() => _brandId = v),
                ),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  // ---- Pricing (product-level prices, not tiers) ----
  Widget _buildPriceInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: AppTextField(
                  controller: _costPriceCtrl,
                  label: 'Cost price',
                  prefixIcon: Icons.payments_outlined,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}))),
          const SizedBox(width: AppSpacing.md),
          Expanded(
              child: AppTextField(
                  controller: _sellingPriceCtrl,
                  label: 'Selling price',
                  prefixIcon: Icons.sell_outlined,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}))),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: _marginField()),
        ]),
        const SizedBox(height: AppSpacing.fieldGap),
        Row(children: [
          Expanded(child: AppTextField(controller: _minPriceCtrl, label: 'Min price', prefixIcon: Icons.trending_down, hint: 'Optional', keyboardType: TextInputType.number)),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: AppTextField(controller: _wholesalePriceCtrl, label: 'Wholesale', prefixIcon: Icons.storefront_outlined, hint: 'Optional', keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: AppSpacing.fieldGap),
        AppTextField(controller: _taxRateCtrl, label: 'Tax rate %', prefixIcon: Icons.percent, keyboardType: TextInputType.number),
        const SizedBox(height: 6),
        _toggleRow('Tax inclusive', _taxInclusive, (v) => setState(() => _taxInclusive = v)),
      ],
    );
  }

  // Live margin: (selling - cost) / selling. Read-only computed well — builds
  // trust versus two static numbers side by side.
  Widget _marginField() {
    final lum = context.lum;
    final cost = double.tryParse(_costPriceCtrl.text) ?? 0;
    final sell = double.tryParse(_sellingPriceCtrl.text) ?? 0;
    final hasMargin = sell > 0;
    final margin = hasMargin ? (sell - cost) / sell * 100 : 0;
    final positive = margin >= 0;
    final color = !hasMargin
        ? lum.g400
        : positive
            ? lum.successText
            : lum.dangerText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Margin'),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: lum.surface2,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          alignment: Alignment.centerLeft,
          child: Row(children: [
            Icon(positive ? Icons.trending_up : Icons.trending_down,
                size: 18, color: color),
            const SizedBox(width: 10),
            Text(
              hasMargin ? '${margin.toStringAsFixed(1)}%' : '—',
              style: AppTypography.fieldText
                  .copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ]),
        ),
      ],
    );
  }

  // ---- Inventory ----
  Widget _buildInventorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(child: AppTextField(controller: _unitCtrl, label: 'Unit of measure', prefixIcon: Icons.straighten, hint: 'PCS')),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: AppTextField(controller: _weightCtrl, label: 'Weight (kg)', prefixIcon: Icons.monitor_weight_outlined, hint: 'Optional', keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: AppSpacing.fieldGap),
        Row(children: [
          Expanded(child: AppTextField(controller: _reorderPointCtrl, label: 'Reorder point', prefixIcon: Icons.warning_amber, keyboardType: TextInputType.number)),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: AppTextField(controller: _reorderQtyCtrl, label: 'Reorder qty', prefixIcon: Icons.add_shopping_cart, keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: AppSpacing.fieldGap),
        _fieldLabel('Status'),
        AppDropdown<String>(
          value: _status,
          options: const [
            AppDropdownOption(value: 'ACTIVE', label: 'Active'),
            AppDropdownOption(value: 'INACTIVE', label: 'Inactive'),
            AppDropdownOption(value: 'DISCONTINUED', label: 'Discontinued'),
          ],
          onSelected: (v) => setState(() => _status = v),
        ),
        const SizedBox(height: AppSpacing.fieldGap),
        AppTextField(controller: _tagsCtrl, label: 'Tags', prefixIcon: Icons.label_outline, hint: 'Comma-separated'),
      ],
    );
  }

  Widget _twoCol(Widget a, Widget b) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: a),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: b),
        ],
      );

  Widget _scanButton(LumColors lum) {
    return Semantics(
      button: true,
      label: 'Scan barcode',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _scanBarcode,
        child: ClayContainer(
          variant: ClayVariant.soft,
          color: lum.surface,
          borderRadius: AppRadius.sm,
          isDark: lum.isDark,
          width: 50,
          height: 50,
          child: Icon(LucideIcons.scanLine, size: 20, color: lum.g600),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text,
          style: AppTypography.footnote
              .copyWith(fontWeight: FontWeight.w600, color: lum.g700)),
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    final lum = context.lum;
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: AppTypography.body.copyWith(color: lum.textPrimary)),
        ),
        AppToggle(value: value, onChanged: onChanged, semanticLabel: label),
      ],
    );
  }

  // Sticky footer: Active toggle always visible next to Save, so save never
  // requires scrolling to the bottom.
  Widget _stickyBar(LumColors lum) {
    final showClose = !_subSectionsEnabled;
    return Container(
      decoration: BoxDecoration(
        color: lum.surface,
        border: Border(top: BorderSide(color: lum.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              AppToggle(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  semanticLabel: 'Active'),
              const SizedBox(width: 10),
              Text('Active',
                  style: AppTypography.footnote
                      .copyWith(color: lum.g600, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (showClose) ...[
                PermissionGate(
                  module: 'inventory',
                  action: 'create',
                  child: AppButton(
                    label: 'Save & close',
                    variant: AppButtonVariant.tinted,
                    loading: _saving,
                    onPressed: _saveAndClose,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              PermissionGate(
                module: 'inventory',
                action: _isEditing ? 'update' : 'create',
                child: AppButton(
                  label: 'Save',
                  loading: _saving,
                  onPressed: _saveCore,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Variants ----
  Widget _buildVariantsSection(List<ProductVariant> variants) {
    return _SubSection(
      title: 'Variants',
      count: variants.length,
      addLabel: 'Add variant',
      onAdd: () => _showVariantSheet(null),
      children: variants
          .map((v) => _SubRow(
                title: v.variantName,
                subtitle:
                    'SKU ${v.sku} · ${v.sellingPrice.toStringAsFixed(2)}',
                onEdit: () => _showVariantSheet(v),
                onDelete: () =>
                    ref.read(productEditProvider.notifier).deleteVariant(v.id),
              ))
          .toList(),
    );
  }

  void _showVariantSheet(ProductVariant? existing) {
    final nameCtrl = TextEditingController(text: existing?.variantName ?? '');
    final skuCtrl = TextEditingController(text: existing?.sku ?? '');
    final barcodeCtrl = TextEditingController(text: existing?.barcode ?? '');
    final costCtrl = TextEditingController(text: existing?.costPrice.toString() ?? '');
    final priceCtrl = TextEditingController(text: existing?.sellingPrice.toString() ?? '');
    final weightCtrl = TextEditingController(text: existing?.weight?.toString() ?? '');
    final attrCtrl = TextEditingController(text: existing?.attributes.entries.map((e) => '${e.key}:${e.value}').join(', ') ?? '');

    showAppSheet<void>(
      context: context,
      builder: (ctx) => _EditSheet(
        title: existing != null ? 'Edit variant' : 'Add variant',
        fields: [
          AppTextField(controller: nameCtrl, label: 'Name', prefixIcon: Icons.style_outlined, hint: 'e.g. 128GB Black'),
          AppTextField(controller: skuCtrl, label: 'SKU', prefixIcon: Icons.tag),
          AppTextField(controller: barcodeCtrl, label: 'Barcode', prefixIcon: Icons.qr_code, hint: 'Optional'),
          AppTextField(controller: costCtrl, label: 'Cost price', prefixIcon: Icons.payments_outlined, keyboardType: TextInputType.number),
          AppTextField(controller: priceCtrl, label: 'Selling price', prefixIcon: Icons.sell_outlined, keyboardType: TextInputType.number),
          AppTextField(controller: weightCtrl, label: 'Weight', prefixIcon: Icons.monitor_weight_outlined, hint: 'Optional', keyboardType: TextInputType.number),
          AppTextField(controller: attrCtrl, label: 'Attributes', prefixIcon: Icons.data_object, hint: 'color:Black, storage:128GB'),
        ],
        onSave: () async {
          final attrs = <String, dynamic>{};
          for (final pair in attrCtrl.text.split(',')) {
            final parts = pair.split(':');
            if (parts.length == 2) attrs[parts[0].trim()] = parts[1].trim();
          }
          final data = {
            'product_id': ref.read(productEditProvider.notifier).editingId,
            'variant_name': nameCtrl.text.trim(),
            'sku': skuCtrl.text.trim(),
            'barcode': barcodeCtrl.text.trim().isEmpty ? null : barcodeCtrl.text.trim(),
            'cost_price': double.tryParse(costCtrl.text) ?? 0,
            'selling_price': double.tryParse(priceCtrl.text) ?? 0,
            'weight': weightCtrl.text.isEmpty ? null : double.tryParse(weightCtrl.text),
            'attributes_json': attrs,
            'is_active': true,
          };
          await ref.read(productEditProvider.notifier).saveVariant(data, id: existing?.id);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  // ---- Images ----
  Widget _buildImagesSection(List<ProductImage> images) {
    final lum = context.lum;
    return AppSectionCard(
      eyebrow: 'Images (${images.length})',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final img in images) _ImageTile(
            image: img,
            onSetPrimary: img.isPrimary
                ? null
                : () => ref
                    .read(productEditProvider.notifier)
                    .setPrimaryImage(img.id),
            onDelete: () =>
                ref.read(productEditProvider.notifier).deleteImage(img.id),
          ),
          if (_uploadingImage) _UploadingTile(lum: lum),
          _AddImageTile(lum: lum, onTap: _showAddImageSheet),
        ],
      ),
    );
  }

  void _showAddImageSheet() {
    showAppSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppSheetHeader(title: 'Add image'),
            AppButton(
              label: 'Upload from device',
              icon: LucideIcons.upload,
              fullWidth: true,
              onPressed: () async {
                Navigator.pop(ctx);
                await _pickAndUploadImage();
              },
            ),
            const SizedBox(height: AppSpacing.fieldGap),
            AppButton(
              label: 'Paste image URL',
              icon: LucideIcons.link,
              variant: AppButtonVariant.tinted,
              fullWidth: true,
              onPressed: () {
                Navigator.pop(ctx);
                _showUrlImageSheet();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = await file.readAsBytes();
    final ext = file.extension ?? 'jpg';
    setState(() => _uploadingImage = true);
    final failure =
        await ref.read(productEditProvider.notifier).uploadImage(bytes, ext);
    if (!mounted) return;
    setState(() => _uploadingImage = false);
    showAppToast(
      context,
      failure?.message ?? 'Image uploaded',
      type: failure != null ? BannerType.error : BannerType.success,
    );
  }

  void _showUrlImageSheet() {
    final urlCtrl = TextEditingController();
    showAppSheet<void>(
      context: context,
      builder: (ctx) => _EditSheet(
        title: 'Add image URL',
        fields: [
          AppTextField(controller: urlCtrl, label: 'Image URL', prefixIcon: Icons.link, hint: 'https://…'),
        ],
        onSave: () async {
          final data = {
            'product_id': ref.read(productEditProvider.notifier).editingId,
            'url': urlCtrl.text.trim(),
            'sort_order': 0,
            'is_primary': false,
          };
          await ref.read(productEditProvider.notifier).addImage(data);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  // ---- Pricing tiers ----
  Widget _buildPricingSection(List<PricingTier> tiers) {
    return _SubSection(
      title: 'Pricing tiers',
      count: tiers.length,
      addLabel: 'Add tier',
      onAdd: () => _showPricingSheet(null),
      children: tiers
          .map((t) => _SubRow(
                title: t.tierName,
                subtitle:
                    'Qty ${t.minQty}${t.maxQty != null ? '-${t.maxQty}' : '+'} · ${t.unitPrice.toStringAsFixed(2)}',
                onEdit: () => _showPricingSheet(t),
                onDelete: () => ref
                    .read(productEditProvider.notifier)
                    .deletePricingTier(t.id),
              ))
          .toList(),
    );
  }

  void _showPricingSheet(PricingTier? existing) {
    final nameCtrl = TextEditingController(text: existing?.tierName ?? '');
    final minCtrl = TextEditingController(text: existing?.minQty.toString() ?? '1');
    final maxCtrl = TextEditingController(text: existing?.maxQty?.toString() ?? '');
    final priceCtrl = TextEditingController(text: existing?.unitPrice.toString() ?? '');
    final discCtrl = TextEditingController(text: existing?.discountPct?.toString() ?? '');

    showAppSheet<void>(
      context: context,
      builder: (ctx) => _EditSheet(
        title: existing != null ? 'Edit tier' : 'Add tier',
        fields: [
          AppTextField(controller: nameCtrl, label: 'Tier name', prefixIcon: Icons.layers_outlined, hint: 'e.g. Wholesale'),
          AppTextField(controller: minCtrl, label: 'Min qty', prefixIcon: Icons.numbers, keyboardType: TextInputType.number),
          AppTextField(controller: maxCtrl, label: 'Max qty', prefixIcon: Icons.numbers, hint: 'Optional', keyboardType: TextInputType.number),
          AppTextField(controller: priceCtrl, label: 'Unit price', prefixIcon: Icons.payments_outlined, keyboardType: TextInputType.number),
          AppTextField(controller: discCtrl, label: 'Discount %', prefixIcon: Icons.percent, hint: 'Optional', keyboardType: TextInputType.number),
        ],
        onSave: () async {
          final data = <String, dynamic>{
            'product_id': ref.read(productEditProvider.notifier).editingId,
            'tier_name': nameCtrl.text.trim(),
            'min_qty': int.tryParse(minCtrl.text) ?? 1,
            'max_qty': maxCtrl.text.isEmpty ? null : int.tryParse(maxCtrl.text),
            'unit_price': double.tryParse(priceCtrl.text) ?? 0,
            'discount_pct': discCtrl.text.isEmpty ? null : double.tryParse(discCtrl.text),
            'is_active': true,
          };
          await ref.read(productEditProvider.notifier).savePricingTier(data, id: existing?.id);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  static String _typeLabel(String t) {
    switch (t) {
      case 'SERIALIZED': return 'Serialized';
      case 'SERVICE': return 'Service';
      case 'COMPOSITE': return 'Composite';
      default: return 'Standard';
    }
  }

  static String _productTypeToString(ProductType t) {
    switch (t) {
      case ProductType.serialized: return 'SERIALIZED';
      case ProductType.service: return 'SERVICE';
      case ProductType.composite: return 'COMPOSITE';
      case ProductType.standard: return 'STANDARD';
    }
  }

  static String _productStatusToString(ProductStatus s) {
    switch (s) {
      case ProductStatus.inactive: return 'INACTIVE';
      case ProductStatus.discontinued: return 'DISCONTINUED';
      case ProductStatus.active: return 'ACTIVE';
    }
  }
}

// ---- Shared widgets ----

const double _kTileSize = 88;

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.image,
    required this.onSetPrimary,
    required this.onDelete,
  });

  final ProductImage image;
  final VoidCallback? onSetPrimary;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return SizedBox(
      width: _kTileSize,
      height: _kTileSize,
      child: Stack(
        children: [
          GestureDetector(
            onTap: onSetPrimary,
            child: Container(
              width: _kTileSize,
              height: _kTileSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: image.isPrimary ? lum.accent : lum.hairline,
                  width: image.isPrimary ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md - 1),
                child: Image.network(
                  image.url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: lum.surface2,
                    child: Icon(Icons.broken_image_outlined,
                        size: 22, color: lum.g500),
                  ),
                ),
              ),
            ),
          ),
          if (image.isPrimary)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: lum.accent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text('Primary',
                    style: AppTypography.caption.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          Positioned(
            top: 2,
            right: 2,
            child: Semantics(
              button: true,
              label: 'Delete image',
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: lum.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: lum.hairline),
                  ),
                  child: Icon(LucideIcons.x, size: 13, color: lum.dangerText),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadingTile extends StatelessWidget {
  const _UploadingTile({required this.lum});
  final LumColors lum;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kTileSize,
      height: _kTileSize,
      decoration: BoxDecoration(
        color: lum.surface2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: lum.hairline),
      ),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(lum.accent),
          ),
        ),
      ),
    );
  }
}

class _AddImageTile extends StatelessWidget {
  const _AddImageTile({required this.lum, required this.onTap});
  final LumColors lum;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add image',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: _kTileSize,
          height: _kTileSize,
          decoration: BoxDecoration(
            color: lum.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: lum.g300),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.plus, size: 20, color: lum.g500),
              const SizedBox(height: 4),
              Text('Add',
                  style: AppTypography.caption.copyWith(color: lum.g500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubSection extends StatelessWidget {
  const _SubSection({
    required this.title,
    required this.count,
    required this.addLabel,
    required this.onAdd,
    required this.children,
  });

  final String title;
  final int count;
  final String addLabel;
  final VoidCallback onAdd;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      eyebrow: '$title ($count)',
      trailing: AppButton(
        label: addLabel,
        icon: LucideIcons.plus,
        variant: AppButtonVariant.plain,
        size: AppButtonSize.sm,
        onPressed: onAdd,
      ),
      child: children.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Nothing added yet.',
                  style: AppTypography.footnote
                      .copyWith(color: context.lum.g400)),
            )
          : Column(children: children),
    );
  }
}

class _SubRow extends StatelessWidget {
  const _SubRow({
    required this.title,
    this.subtitle,
    this.onEdit,
    this.onDelete,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClayContainer(
        variant: ClayVariant.inset,
        color: lum.surface2,
        borderRadius: AppRadius.md,
        isDark: lum.isDark,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.callout
                          .copyWith(fontWeight: FontWeight.w600, color: lum.textPrimary)),
                  if (subtitle != null)
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.footnote
                            .copyWith(color: lum.g500)),
                ],
              ),
            ),
            if (onEdit != null)
              IconButton(
                icon: Icon(LucideIcons.pencil, size: 18, color: lum.accent),
                onPressed: onEdit,
              ),
            if (onDelete != null)
              IconButton(
                icon: Icon(LucideIcons.x, size: 18, color: lum.dangerText),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

class _EditSheet extends StatelessWidget {
  const _EditSheet({
    required this.title,
    required this.fields,
    required this.onSave,
  });

  final String title;
  final List<Widget> fields;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSheetHeader(title: title),
            for (final f in fields) ...[
              f,
              const SizedBox(height: AppSpacing.fieldGap),
            ],
            const SizedBox(height: 4),
            AppButton(label: 'Save', fullWidth: true, onPressed: onSave),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
