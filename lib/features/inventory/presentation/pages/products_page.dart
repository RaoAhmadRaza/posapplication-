import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../../domain/entities/product.dart';
import '../controllers/categories_controller.dart';
import '../controllers/products_controller.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String? _filterCategoryId;
  String? _filterStatus;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchTextChanged() {
    final value = _searchController.text;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _isSearching = value.trim().isNotEmpty);
      ref.read(productsProvider.notifier).search(value);
    });
  }

  void _onFilterChanged({String? categoryId, String? status}) {
    setState(() {
      _filterCategoryId = categoryId;
      _filterStatus = status;
      _searchController.clear();
      _isSearching = false;
    });
    ref.read(productsProvider.notifier).load(
          categoryId: categoryId,
          status: status,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsProvider);
    final categories = ref.watch(categoriesProvider).value ?? <Category>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Products', style: AppTypography.headline),
        actions: [
          PermissionGate(
            module: 'inventory',
            action: 'create',
            child: IconButton(
              icon: const Icon(Icons.add, color: AppColors.accent),
              onPressed: () => context.push('/inventory/products/create'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _searchController,
                  label: 'Search',
                  prefixIcon: Icons.search,
                  hint: 'Name, SKU, or barcode',
                ),
                const SizedBox(height: AppSpacing.sm),
                _FilterRow(
                  categories: categories,
                  selectedCategoryId: _filterCategoryId,
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
                onPressed: _isSearching
                    ? () => ref.read(productsProvider.notifier).search(_searchController.text)
                    : () => ref.read(productsProvider.notifier).load(
                          categoryId: _filterCategoryId,
                          status: _filterStatus,
                        ),
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
            vertical: AppSpacing.md,
          ),
          itemCount: products.length,
          itemBuilder: (_, i) => Padding(
            padding: EdgeInsets.only(
              bottom: i < products.length - 1 ? AppSpacing.md : 0,
            ),
            child: _ProductCard(product: products[i]),
          ),
        );
      },
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.categories,
    required this.selectedCategoryId,
    required this.selectedStatus,
    required this.onChanged,
  });

  final List<Category> categories;
  final String? selectedCategoryId;
  final String? selectedStatus;
  final void Function({String? categoryId, String? status}) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DropdownChip(
            label: selectedCategoryId != null
                ? categories.where((c) => c.id == selectedCategoryId).firstOrNull?.name ?? 'Category'
                : 'Category',
            active: selectedCategoryId != null,
            onClear: selectedCategoryId != null
                ? () => onChanged(categoryId: null, status: selectedStatus)
                : null,
            onTap: () => _showCategoryPicker(context),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _DropdownChip(
            label: _statusLabel(selectedStatus),
            active: selectedStatus != null,
            onClear: selectedStatus != null
                ? () => onChanged(categoryId: selectedCategoryId, status: null)
                : null,
            onTap: () => _showStatusPicker(context),
          ),
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
                onChanged(categoryId: null, status: selectedStatus);
              },
            ),
            ...categories.map((c) => ListTile(
                  title: Text(c.name),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onChanged(categoryId: c.id, status: selectedStatus);
                  },
                )),
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
                onChanged(categoryId: selectedCategoryId, status: null);
              },
            ),
            ...['ACTIVE', 'INACTIVE', 'DISCONTINUED'].map((s) => ListTile(
                  title: Text(_statusLabel(s)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onChanged(categoryId: selectedCategoryId, status: s);
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
  const _ProductCard({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).value ?? <Category>[];
    final categoryName = categories
        .where((c) => c.id == product.categoryId)
        .firstOrNull
        ?.name;

    return AppCard(
      child: InkWell(
        onTap: () => context.push('/inventory/products/${product.id}'),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
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
                    'PKR ${product.sellingPrice.toStringAsFixed(2)}',
                    style: AppTypography.headline.copyWith(color: AppColors.accent),
                  ),
                  const Spacer(),
                  Text(
                    'Stock: ${product.reorderPoint}',
                    style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
                  ),
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
