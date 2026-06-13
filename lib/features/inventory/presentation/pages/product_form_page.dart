import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/permission_gate.dart';
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
  bool _loadingExisting = false;
  bool _hasSavedOnce = false;

  bool get _isEditing => widget.productId != null;
  bool get _subSectionsEnabled => _isEditing || _hasSavedOnce;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      Future.microtask(() {
        ref.read(productEditProvider.notifier).loadForEdit(widget.productId!);
        _loadingExisting = true;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadingExisting) {
      final productState = ref.read(productEditProvider);
      if (productState.value != null) {
        _loadExisting(productState.value!);
      }
    }
  }

  void _loadExisting(Product p) {
    if (!_loadingExisting) return;
    _loadingExisting = false;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product saved. You can now add variants, images, and pricing.')),
      );
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

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Delete this product? It will be soft-deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.destructive)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(productEditProvider.notifier).deleteProduct();
    ref.invalidate(productsProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? <Category>[];
    final editState = ref.watch(productEditProvider);
    final variants = editState.value != null ? ref.read(productEditProvider.notifier).variantsState.variants : <ProductVariant>[];
    final images = editState.value != null ? ref.read(productEditProvider.notifier).imagesState.images : <ProductImage>[];
    final tiers = editState.value != null ? ref.read(productEditProvider.notifier).pricingState.tiers : <PricingTier>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_isEditing ? 'Edit Product' : 'New Product', style: AppTypography.headline),
        actions: [
          if (_isEditing)
            PermissionGate(
              module: 'inventory',
              action: 'delete',
              child: IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.destructive),
                onPressed: _confirmDelete,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              if (_error != null) ...[
                AppInlineBanner(message: _error!, type: BannerType.error),
                const SizedBox(height: AppSpacing.lg),
              ],
              _buildCoreSection(),
              const SizedBox(height: AppSpacing.lg),
              _buildSaveRow(),
              if (_subSectionsEnabled) ...[
                const SizedBox(height: AppSpacing.xxl),
                _buildVariantsSection(variants, categories),
                const SizedBox(height: AppSpacing.lg),
                _buildImagesSection(images),
                const SizedBox(height: AppSpacing.lg),
                _buildPricingSection(tiers),
              ],
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoreSection() {
    final categoriesAsync = ref.watch(categoriesProvider);
    final brandsAsync = ref.watch(brandsProvider);
    final categories = categoriesAsync.value ?? <Category>[];
    final brands = brandsAsync.value ?? <Brand>[];
    final catsLoading = categoriesAsync.isLoading && categories.isEmpty;
    final brandsLoading = brandsAsync.isLoading && brands.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(controller: _nameCtrl, label: 'Name', prefixIcon: Icons.inventory_2, hint: 'Product name'),
        const SizedBox(height: AppSpacing.fieldGap),
        AppTextField(controller: _barcodeCtrl, label: 'Barcode', prefixIcon: Icons.barcode_reader, hint: 'Optional'),
        const SizedBox(height: AppSpacing.fieldGap),
        AppTextField(controller: _descriptionCtrl, label: 'Description', prefixIcon: Icons.description, hint: 'Optional'),
        const SizedBox(height: AppSpacing.fieldGap),
        _DropdownField(label: 'Type', value: _type, items: const ['STANDARD', 'SERIALIZED', 'SERVICE', 'COMPOSITE'], onChanged: (v) => setState(() => _type = v)),
        const SizedBox(height: AppSpacing.fieldGap),
        _PickerField(
          label: 'Category', value: _categoryId,
          items: categories, display: (c) => c.name, id: (c) => c.id,
          hint: catsLoading ? 'Loading...' : 'None', enabled: !catsLoading,
          onChanged: (v) => setState(() => _categoryId = v),
        ),
        const SizedBox(height: AppSpacing.fieldGap),
        _PickerField(
          label: 'Brand', value: _brandId,
          items: brands, display: (b) => b.name, id: (b) => b.id,
          hint: brandsLoading ? 'Loading...' : 'None', enabled: !brandsLoading,
          onChanged: (v) => setState(() => _brandId = v),
        ),
        const SizedBox(height: AppSpacing.fieldGap),
        AppTextField(controller: _unitCtrl, label: 'Unit of Measure', prefixIcon: Icons.straighten, hint: 'PCS'),
        const SizedBox(height: AppSpacing.fieldGap),
        Row(children: [
          Expanded(child: AppTextField(controller: _costPriceCtrl, label: 'Cost Price', prefixIcon: Icons.attach_money, keyboardType: TextInputType.number)),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: AppTextField(controller: _sellingPriceCtrl, label: 'Selling Price', prefixIcon: Icons.sell, keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: AppSpacing.fieldGap),
        Row(children: [
          Expanded(child: AppTextField(controller: _minPriceCtrl, label: 'Min Price', prefixIcon: Icons.trending_down, hint: 'Optional', keyboardType: TextInputType.number)),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: AppTextField(controller: _wholesalePriceCtrl, label: 'Wholesale', prefixIcon: Icons.store, hint: 'Optional', keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: AppSpacing.fieldGap),
        Row(children: [
          Expanded(child: AppTextField(controller: _taxRateCtrl, label: 'Tax Rate %', prefixIcon: Icons.percent, keyboardType: TextInputType.number)),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Padding(
            padding: const EdgeInsets.only(top: 28),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Tax inclusive', style: AppTypography.footnote),
              value: _taxInclusive, activeThumbColor: AppColors.accent,
              onChanged: (v) => setState(() => _taxInclusive = v),
            ),
          )),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Row(children: [
          Expanded(child: AppTextField(controller: _reorderPointCtrl, label: 'Reorder Point', prefixIcon: Icons.warning_amber, keyboardType: TextInputType.number)),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: AppTextField(controller: _reorderQtyCtrl, label: 'Reorder Qty', prefixIcon: Icons.add_shopping_cart, keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: AppSpacing.fieldGap),
        AppTextField(controller: _weightCtrl, label: 'Weight (kg)', prefixIcon: Icons.monitor_weight, hint: 'Optional', keyboardType: TextInputType.number),
        const SizedBox(height: AppSpacing.fieldGap),
        _DropdownField(label: 'Status', value: _status, items: const ['ACTIVE', 'INACTIVE', 'DISCONTINUED'], onChanged: (v) => setState(() => _status = v)),
        const SizedBox(height: AppSpacing.fieldGap),
        SwitchListTile(
          contentPadding: EdgeInsets.zero, title: Text('Active', style: AppTypography.body),
          value: _isActive, activeThumbColor: AppColors.accent,
          onChanged: (v) => setState(() => _isActive = v),
        ),
        const SizedBox(height: AppSpacing.fieldGap),
        AppTextField(controller: _tagsCtrl, label: 'Tags', prefixIcon: Icons.label, hint: 'Comma-separated'),
      ],
    );
  }

  Widget _buildSaveRow() {
    return Row(
      children: [
        Expanded(
          child: PermissionGate(
            module: 'inventory',
            action: _isEditing ? 'update' : 'create',
            child: AppButton(
              label: 'Save',
              loading: _saving,
              onPressed: _saveCore,
            ),
          ),
        ),
        if (!_subSectionsEnabled) ...[
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: PermissionGate(
              module: 'inventory',
              action: 'create',
              child: AppButton(
                label: 'Save & Close',
                variant: AppButtonVariant.tinted,
                loading: _saving,
                onPressed: _saveAndClose,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ---- Variants ----
  Widget _buildVariantsSection(List<ProductVariant> variants, List<Category> categories) {
    return _CollapsibleSection(
      title: 'Variants (${variants.length})',
      initiallyExpanded: variants.isNotEmpty,
      addLabel: 'Add Variant',
      onAdd: () => _showVariantDialog(null),
      child: variants.isEmpty
          ? _emptyHint('No variants')
          : Column(
              children: variants.map((v) => _VariantCard(
                    variant: v,
                    onEdit: () => _showVariantDialog(v),
                    onDelete: () => ref.read(productEditProvider.notifier).deleteVariant(v.id),
                  )).toList(),
            ),
    );
  }

  void _showVariantDialog(ProductVariant? existing) {
    final nameCtrl = TextEditingController(text: existing?.variantName ?? '');
    final skuCtrl = TextEditingController(text: existing?.sku ?? '');
    final barcodeCtrl = TextEditingController(text: existing?.barcode ?? '');
    final costCtrl = TextEditingController(text: existing?.costPrice.toString() ?? '');
    final priceCtrl = TextEditingController(text: existing?.sellingPrice.toString() ?? '');
    final weightCtrl = TextEditingController(text: existing?.weight?.toString() ?? '');
    final attrCtrl = TextEditingController(text: existing?.attributes.entries.map((e) => '${e.key}:${e.value}').join(', ') ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing != null ? 'Edit Variant' : 'Add Variant'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. 128GB Black')),
              const SizedBox(height: AppSpacing.sm),
              TextField(controller: skuCtrl, decoration: const InputDecoration(labelText: 'SKU')),
              const SizedBox(height: AppSpacing.sm),
              TextField(controller: barcodeCtrl, decoration: const InputDecoration(labelText: 'Barcode (optional)')),
              const SizedBox(height: AppSpacing.sm),
              TextField(controller: costCtrl, decoration: const InputDecoration(labelText: 'Cost Price'), keyboardType: TextInputType.number),
              const SizedBox(height: AppSpacing.sm),
              TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Selling Price'), keyboardType: TextInputType.number),
              const SizedBox(height: AppSpacing.sm),
              TextField(controller: weightCtrl, decoration: const InputDecoration(labelText: 'Weight (optional)'), keyboardType: TextInputType.number),
              const SizedBox(height: AppSpacing.sm),
              TextField(controller: attrCtrl, decoration: const InputDecoration(labelText: 'Attributes', hintText: 'color:Black, storage:128GB')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ---- Images ----
  Widget _buildImagesSection(List<ProductImage> images) {
    final urlCtrl = TextEditingController();
    return _CollapsibleSection(
      title: 'Images (${images.length})',
      initiallyExpanded: images.isNotEmpty,
      addLabel: 'Add Image URL',
      onAdd: () => _showAddImageDialog(urlCtrl),
      child: images.isEmpty
          ? _emptyHint('No images')
          : Column(
              children: images.map((img) => _ImageCard(
                    image: img,
                    onSetPrimary: () => ref.read(productEditProvider.notifier).setPrimaryImage(img.id),
                    onDelete: () => ref.read(productEditProvider.notifier).deleteImage(img.id),
                  )).toList(),
            ),
    );
  }

  void _showAddImageDialog(TextEditingController urlCtrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Image'),
        content: TextField(
          controller: urlCtrl,
          decoration: const InputDecoration(labelText: 'Image URL', hintText: 'https://...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final data = {
                'product_id': ref.read(productEditProvider.notifier).editingId,
                'url': urlCtrl.text.trim(),
                'sort_order': 0,
                'is_primary': false,
              };
              await ref.read(productEditProvider.notifier).addImage(data);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ---- Pricing ----
  Widget _buildPricingSection(List<PricingTier> tiers) {
    return _CollapsibleSection(
      title: 'Pricing Tiers (${tiers.length})',
      initiallyExpanded: tiers.isNotEmpty,
      addLabel: 'Add Tier',
      onAdd: () => _showPricingDialog(null),
      child: tiers.isEmpty
          ? _emptyHint('No pricing tiers')
          : Column(
              children: tiers.map((t) => _PricingCard(
                    tier: t,
                    onEdit: () => _showPricingDialog(t),
                    onDelete: () => ref.read(productEditProvider.notifier).deletePricingTier(t.id),
                  )).toList(),
            ),
    );
  }

  void _showPricingDialog(PricingTier? existing) {
    final nameCtrl = TextEditingController(text: existing?.tierName ?? '');
    final minCtrl = TextEditingController(text: existing?.minQty.toString() ?? '1');
    final maxCtrl = TextEditingController(text: existing?.maxQty?.toString() ?? '');
    final priceCtrl = TextEditingController(text: existing?.unitPrice.toString() ?? '');
    final discCtrl = TextEditingController(text: existing?.discountPct?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing != null ? 'Edit Tier' : 'Add Tier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tier Name', hintText: 'e.g. Wholesale')),
              const SizedBox(height: AppSpacing.sm),
              TextField(controller: minCtrl, decoration: const InputDecoration(labelText: 'Min Qty'), keyboardType: TextInputType.number),
              const SizedBox(height: AppSpacing.sm),
              TextField(controller: maxCtrl, decoration: const InputDecoration(labelText: 'Max Qty (optional)'), keyboardType: TextInputType.number),
              const SizedBox(height: AppSpacing.sm),
              TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Unit Price'), keyboardType: TextInputType.number),
              const SizedBox(height: AppSpacing.sm),
              TextField(controller: discCtrl, decoration: const InputDecoration(labelText: 'Discount % (optional)'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(text, textAlign: TextAlign.center, style: AppTypography.footnote.copyWith(color: AppColors.textHint)),
    );
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

class _DropdownField extends StatelessWidget {
  const _DropdownField({required this.label, required this.value, required this.items, required this.onChanged});
  final String label, value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(label, style: AppTypography.fieldLabel)),
      Container(
        height: 52, padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: AppColors.fieldFill, borderRadius: BorderRadius.circular(12)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value, isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
            items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ),
      ),
    ]);
  }
}

class _PickerField<T> extends StatelessWidget {
  const _PickerField({required this.label, required this.value, required this.items, required this.display, required this.id, required this.hint, required this.onChanged, this.enabled = true});
  final String label;
  final String? value;
  final List<T> items;
  final String Function(T) display;
  final String Function(T) id;
  final String hint;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(label, style: AppTypography.fieldLabel)),
      Container(
        height: 52, padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: AppColors.fieldFill, borderRadius: BorderRadius.circular(12)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: value, isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
            hint: Text(hint, style: AppTypography.fieldHint),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text(hint)),
              ...items.map((i) => DropdownMenuItem<String?>(value: id(i), child: Text(display(i)))),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    ]);
  }
}

class _CollapsibleSection extends StatefulWidget {
  const _CollapsibleSection({required this.title, required this.addLabel, required this.onAdd, required this.child, this.initiallyExpanded = false});
  final String title, addLabel;
  final VoidCallback onAdd;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  late bool _expanded;

  @override
  void initState() { super.initState(); _expanded = widget.initiallyExpanded; }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(widget.title, style: AppTypography.headline)),
            TextButton(
              onPressed: widget.onAdd,
              child: Text(widget.addLabel, style: AppTypography.callout.copyWith(color: AppColors.accent)),
            ),
            IconButton(
              icon: Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.textMuted),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
          ]),
          if (_expanded) widget.child,
        ],
      ),
    );
  }
}

class _VariantCard extends StatelessWidget {
  const _VariantCard({required this.variant, required this.onEdit, required this.onDelete});
  final ProductVariant variant;
  final VoidCallback onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: AppColors.fieldFill, borderRadius: BorderRadius.circular(AppRadius.field)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(variant.variantName, style: AppTypography.callout.copyWith(fontWeight: FontWeight.w600)),
            Text('SKU: ${variant.sku} · ${variant.sellingPrice.toStringAsFixed(2)}', style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
          ])),
          IconButton(icon: const Icon(Icons.edit, size: 18, color: AppColors.accent), onPressed: onEdit),
          IconButton(icon: const Icon(Icons.close, size: 18, color: AppColors.destructive), onPressed: onDelete),
        ]),
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({required this.image, required this.onSetPrimary, required this.onDelete});
  final ProductImage image;
  final VoidCallback onSetPrimary, onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: AppColors.fieldFill, borderRadius: BorderRadius.circular(AppRadius.field)),
        child: Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.separator, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.image, color: AppColors.textMuted, size: 24)),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(image.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.footnote),
            if (image.isPrimary) Text('Primary', style: AppTypography.caption.copyWith(color: AppColors.success)),
          ])),
          if (!image.isPrimary) IconButton(icon: const Icon(Icons.star_outline, size: 18, color: AppColors.textMuted), onPressed: onSetPrimary, tooltip: 'Set as primary'),
          IconButton(icon: const Icon(Icons.close, size: 18, color: AppColors.destructive), onPressed: onDelete),
        ]),
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  const _PricingCard({required this.tier, required this.onEdit, required this.onDelete});
  final PricingTier tier;
  final VoidCallback onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: AppColors.fieldFill, borderRadius: BorderRadius.circular(AppRadius.field)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tier.tierName, style: AppTypography.callout.copyWith(fontWeight: FontWeight.w600)),
            Text('Qty ${tier.minQty}${tier.maxQty != null ? '-${tier.maxQty}' : '+'} · ${tier.unitPrice.toStringAsFixed(2)}', style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
          ])),
          IconButton(icon: const Icon(Icons.edit, size: 18, color: AppColors.accent), onPressed: onEdit),
          IconButton(icon: const Icon(Icons.close, size: 18, color: AppColors.destructive), onPressed: onDelete),
        ]),
      ),
    );
  }
}
