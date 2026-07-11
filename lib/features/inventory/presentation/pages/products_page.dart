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
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/services/scanner_support.dart';
import '../../../../core/services/voice_input_service.dart';
import '../../../../core/services/voice_support.dart';
import '../../../../core/widgets/barcode_scan_page.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/brand.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/product.dart';
import '../controllers/brands_controller.dart';
import '../controllers/categories_controller.dart';
import '../controllers/products_controller.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  bool _loadingMore = false;
  String? _filterCategoryId;
  String? _filterBrandId;
  String? _filterStatus;
  bool _isSearching = false;
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  final _voiceService = VoiceInputService();
  bool _voiceListening = false;
  String _voicePartial = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    _voiceService.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore) return;
    final notifier = ref.read(productsProvider.notifier);
    if (!notifier.hasMore) return;
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - 400) return;
    _loadMore();
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    final failure = await ref.read(productsProvider.notifier).loadMore();
    if (!mounted) return;
    setState(() => _loadingMore = false);
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load more products.')),
      );
    }
  }

  void _onSearchTextChanged() {
    final value = _searchController.text;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _isSearching = value.trim().isNotEmpty);
      _applyFilters();
    });
  }

  void _applyFilters() {
    final q = _searchController.text;
    ref.read(productsProvider.notifier).search(
          q,
          categoryId: _filterCategoryId,
          brandId: _filterBrandId,
          status: _filterStatus,
        );
  }

  void _onFilterChanged({String? categoryId, String? brandId, String? status}) {
    setState(() {
      _filterCategoryId = categoryId;
      _filterBrandId = brandId;
      _filterStatus = status;
    });
    _applyFilters();
  }

  Future<void> _scanForSearch() async {
    final code = await scanBarcode(context, title: 'Scan Product');
    if (code == null || code == BarcodeScanPage.manualEntrySentinel) return;
    _searchController.text = code;
    setState(() => _isSearching = true);
    _applyFilters();
  }

  Future<void> _startVoiceSearch() async {
    if (_voiceListening) {
      _voiceService.cancel();
      setState(() {
        _voiceListening = false;
        _voicePartial = '';
      });
      return;
    }

    setState(() {
      _voiceListening = true;
      _voicePartial = '';
    });

    final result = await _voiceService.listen(
      onPartial: (partial) {
        if (!mounted) return;
        setState(() => _voicePartial = partial);
        _searchController.text = partial;
      },
    );

    if (!mounted) return;
    setState(() {
      _voiceListening = false;
      _voicePartial = '';
    });

    if (result != null && result.isNotEmpty) {
      _searchController.text = result;
      setState(() => _isSearching = true);
      _applyFilters();
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selectedIds.clear();
    });
  }

  void _toggleProduct(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsProvider);
    final categories = ref.watch(categoriesProvider).value ?? <Category>[];
    final brands = ref.watch(brandsProvider).value ?? <Brand>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close, color: AppColors.accent, size: 20),
                onPressed: _toggleSelectionMode,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: _selectionMode
            ? Text('${_selectedIds.length} selected', style: AppTypography.headline)
            : Text('Products', style: AppTypography.headline),
        actions: [
          if (_selectionMode)
            PermissionGate(
              module: 'inventory',
              action: 'create',
              child: IconButton(
                icon: const Icon(Icons.add, color: AppColors.accent),
                onPressed: () => context.push('/inventory/products/create'),
              ),
            )
          else ...[
            PermissionGate(
              module: 'inventory',
              action: 'export',
              child: IconButton(
                icon: const Icon(Icons.local_printshop_outlined, color: AppColors.accent),
                onPressed: _toggleSelectionMode,
                tooltip: 'Print Labels',
              ),
            ),
            PermissionGate(
              module: 'inventory',
              action: 'create',
              child: IconButton(
                icon: const Icon(Icons.add, color: AppColors.accent),
                onPressed: () => context.push('/inventory/products/create'),
              ),
            ),
            PermissionGate(
              module: 'inventory',
              action: 'create',
              child: IconButton(
                icon: const Icon(Icons.upload_file, color: AppColors.accent),
                onPressed: () => context.push('/inventory/import'),
                tooltip: 'Import Products',
              ),
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _searchController,
                            label: 'Search',
                            prefixIcon: Icons.search,
                            hint: 'Name, SKU, or barcode',
                          ),
                        ),
                    if (barcodeScanSupported) ...[
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner, color: AppColors.accent),
                        onPressed: _scanForSearch,
                        tooltip: 'Scan barcode',
                      ),
                    ],
                    if (voiceSearchSupported) ...[
                      const SizedBox(width: AppSpacing.xs),
                      IconButton(
                        icon: Icon(
                          _voiceListening ? Icons.mic : Icons.mic_none,
                          color: _voiceListening ? AppColors.destructive : AppColors.accent,
                        ),
                        onPressed: _startVoiceSearch,
                        tooltip: 'Voice search',
                      ),
                    ],
                  ],
                ),
                if (_voiceListening)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _voicePartial.isNotEmpty
                                ? 'Listening… "$_voicePartial"'
                                : 'Listening…',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.accent,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                    const SizedBox(height: AppSpacing.sm),
                    _FilterRow(
                      categories: categories,
                      brands: brands,
                      selectedCategoryId: _filterCategoryId,
                      selectedBrandId: _filterBrandId,
                      selectedStatus: _filterStatus,
                      onChanged: _onFilterChanged,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(child: _buildBody(state)),
            ],
          ),
          if (_selectionMode && _selectedIds.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildSelectionBar(),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(AsyncValue<List<Product>> state) {
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppInlineBanner(
                message: 'Could not load products.',
                type: BannerType.error,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Retry',
                onPressed: _applyFilters,
              ),
            ],
          ),
        ),
      ),
      data: (products) {
        if (products.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isSearching ? Icons.search_off : Icons.inventory_2_outlined,
                    size: 48,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _isSearching ? 'No products match' : 'No products yet',
                    style: AppTypography.subhead.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _isSearching
                        ? 'Try a different search term or clear filters.'
                        : 'Add your first product to get started.',
                    textAlign: TextAlign.center,
                    style: AppTypography.footnote.copyWith(color: AppColors.textHint),
                  ),
                  if (!_isSearching) ...[
                    const SizedBox(height: AppSpacing.xl),
                    PermissionGate(
                      module: 'inventory',
                      action: 'create',
                      child: AppButton(
                        label: 'Add Product',
                        onPressed: () => context.push('/inventory/products/create'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
            vertical: AppSpacing.md,
          ),
          itemCount: products.length + (_loadingMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (i >= products.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Padding(
              padding: EdgeInsets.only(
                bottom: i < products.length - 1 ? AppSpacing.md : 0,
              ),
              child: _ProductCard(
                product: products[i],
                selected: _selectedIds.contains(products[i].id),
                onToggle: _selectionMode
                    ? () => _toggleProduct(products[i].id)
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSelectionBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border(
            top: BorderSide(color: AppColors.separator, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Text(
              '${_selectedIds.length} item${_selectedIds.length == 1 ? '' : 's'}',
              style: AppTypography.headline,
            ),
            const Spacer(),
            AppButton(
              label: 'Choose Template',
              onPressed: () {
                context.push('/inventory/labels',
                  extra: _selectedIds.toList());
              },
              icon: Icons.arrow_forward,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.categories,
    required this.brands,
    required this.selectedCategoryId,
    required this.selectedBrandId,
    required this.selectedStatus,
    required this.onChanged,
  });

  final List<Category> categories;
  final List<Brand> brands;
  final String? selectedCategoryId;
  final String? selectedBrandId;
  final String? selectedStatus;
  final void Function({String? categoryId, String? brandId, String? status}) onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _DropdownChip(
          label: selectedCategoryId != null
              ? categories.where((c) => c.id == selectedCategoryId).firstOrNull?.name ?? 'Category'
              : 'Category',
          active: selectedCategoryId != null,
          onClear: selectedCategoryId != null
              ? () => onChanged(categoryId: null, brandId: selectedBrandId, status: selectedStatus)
              : null,
          onTap: () => _showCategoryPicker(context),
        ),
        _DropdownChip(
          label: selectedBrandId != null
              ? brands.where((b) => b.id == selectedBrandId).firstOrNull?.name ?? 'Brand'
              : 'Brand',
          active: selectedBrandId != null,
          onClear: selectedBrandId != null
              ? () => onChanged(categoryId: selectedCategoryId, brandId: null, status: selectedStatus)
              : null,
          onTap: () => _showBrandPicker(context),
        ),
        _DropdownChip(
          label: _statusLabel(selectedStatus),
          active: selectedStatus != null,
          onClear: selectedStatus != null
              ? () => onChanged(categoryId: selectedCategoryId, brandId: selectedBrandId, status: null)
              : null,
          onTap: () => _showStatusPicker(context),
        ),
      ],
    );
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'ACTIVE':
        return 'Active';
      case 'INACTIVE':
        return 'Inactive';
      case 'DISCONTINUED':
        return 'Discontinued';
      default:
        return 'Status';
    }
  }

  void _showCategoryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Categories'),
              onTap: () {
                Navigator.of(ctx).pop();
                onChanged(categoryId: null, brandId: selectedBrandId, status: selectedStatus);
              },
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: categories
                    .map((c) => ListTile(
                          title: Text(c.name),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            onChanged(categoryId: c.id, brandId: selectedBrandId, status: selectedStatus);
                          },
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBrandPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Brands'),
              onTap: () {
                Navigator.of(ctx).pop();
                onChanged(categoryId: selectedCategoryId, brandId: null, status: selectedStatus);
              },
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: brands
                    .map((b) => ListTile(
                          title: Text(b.name),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            onChanged(categoryId: selectedCategoryId, brandId: b.id, status: selectedStatus);
                          },
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All'),
              onTap: () {
                Navigator.of(ctx).pop();
                onChanged(categoryId: selectedCategoryId, brandId: selectedBrandId, status: null);
              },
            ),
            ...['ACTIVE', 'INACTIVE', 'DISCONTINUED'].map((s) => ListTile(
                  title: Text(_statusLabel(s)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onChanged(categoryId: selectedCategoryId, brandId: selectedBrandId, status: s);
                  },
                )),
          ],
        ),
      ),
    );
  }
}

class _DropdownChip extends StatelessWidget {
  const _DropdownChip({
    required this.label,
    required this.active,
    this.onClear,
    this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback? onClear;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: active ? AppColors.accent.withValues(alpha: 0.1) : AppColors.fieldFill,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: active ? Border.all(color: AppColors.accent, width: 1) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.footnote.copyWith(
                color: active ? AppColors.accent : AppColors.textMuted,
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 16, color: AppColors.accent),
              ),
            ],
            const Spacer(),
            Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.product, this.selected = false, this.onToggle});
  final Product product;
  final bool selected;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).value ?? <Category>[];
    final categoryName = categories
        .where((c) => c.id == product.categoryId)
        .firstOrNull
        ?.name;

    return AppCard(
      child: InkWell(
        onTap: selected
            ? onToggle
            : () => context.push('/inventory/products/${product.id}'),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (onToggle != null) ...[
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: selected,
                        onChanged: (_) => onToggle!(),
                        activeColor: AppColors.accent,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
                        style: AppTypography.headline.copyWith(color: AppColors.accent),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name, style: AppTypography.headline),
                        const SizedBox(height: 2),
                        Text(
                          _buildSubtitle(categoryName),
                          style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  _ProductStatusChip(product: product),
                ],
              ),
              const Divider(color: AppColors.separator, height: AppSpacing.xl),
              Row(
                children: [
                  Text(
                    formatPkr(product.sellingPrice),
                    style: AppTypography.headline.copyWith(color: AppColors.accent),
                  ),
                  const Spacer(),
                  _StockLabel(product: product),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildSubtitle(String? categoryName) {
    final parts = <String>[];
    if (product.sku.isNotEmpty) parts.add('SKU: ${product.sku}');
    if (product.barcode != null && product.barcode!.isNotEmpty) {
      parts.add('Barcode: ${product.barcode}');
    }
    if (categoryName != null) parts.add(categoryName);
    return parts.join(' · ');
  }
}

class _StockLabel extends StatelessWidget {
  const _StockLabel({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final qty = product.qtyOnHand;
    if (qty == null) {
      return Text(
        'Stock: —',
        style: AppTypography.footnote.copyWith(color: AppColors.textHint),
      );
    }
    if (qty <= 0) {
      return Text(
        'Stock: Out',
        style: AppTypography.footnote.copyWith(color: AppColors.destructive, fontWeight: FontWeight.w600),
      );
    }
    if (qty <= product.reorderPoint) {
      return Text(
        'Stock: Low (${qty.toStringAsFixed(0)})',
        style: AppTypography.footnote.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600),
      );
    }
    return Text(
      'Stock: ${qty.toStringAsFixed(0)}',
      style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
    );
  }
}

class _ProductStatusChip extends StatelessWidget {
  const _ProductStatusChip({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (product.status) {
      ProductStatus.active => (AppColors.success, 'Active'),
      ProductStatus.inactive => (AppColors.textMuted, 'Inactive'),
      ProductStatus.discontinued => (AppColors.warning, 'Disc.'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
