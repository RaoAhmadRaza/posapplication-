import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_checkbox.dart';
import '../../../../core/design/widgets/app_list_skeleton.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_search_field.dart';
import '../../../../core/design/widgets/app_sheet.dart';
import '../../../../core/design/widgets/app_states.dart';
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
import '../widgets/inventory_ui.dart';

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
    final lum = context.lum;
    final state = ref.watch(productsProvider);
    final categories = ref.watch(categoriesProvider).value ?? <Category>[];
    final brands = ref.watch(brandsProvider).value ?? <Brand>[];

    return Scaffold(
      backgroundColor: lum.paper,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _header(lum),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppSearchField(
                              controller: _searchController,
                              hint: 'Search name, SKU or barcode',
                            ),
                          ),
                          if (barcodeScanSupported) ...[
                            const SizedBox(width: 10),
                            _ToolIcon(
                              icon: LucideIcons.scanLine,
                              tooltip: 'Scan barcode',
                              onTap: _scanForSearch,
                            ),
                          ],
                          if (voiceSearchSupported) ...[
                            const SizedBox(width: 8),
                            _ToolIcon(
                              icon: _voiceListening
                                  ? LucideIcons.mic
                                  : LucideIcons.micOff,
                              tooltip: 'Voice search',
                              active: _voiceListening,
                              onTap: _startVoiceSearch,
                            ),
                          ],
                        ],
                      ),
                      if (_voiceListening)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: lum.accentSoft,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                            ),
                            child: Row(
                              children: [
                                Icon(LucideIcons.mic,
                                    size: 16, color: lum.accentPress),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    _voicePartial.isNotEmpty
                                        ? 'Listening… "$_voicePartial"'
                                        : 'Listening…',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.footnote.copyWith(
                                      color: lum.accentPress,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      _FilterRow(
                        categories: categories,
                        brands: brands,
                        selectedCategoryId: _filterCategoryId,
                        selectedBrandId: _filterBrandId,
                        selectedStatus: _filterStatus,
                        onChanged: _onFilterChanged,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                Expanded(child: _buildBody(state)),
              ],
            ),
            if (_selectionMode && _selectedIds.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildSelectionBar(lum),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header(LumColors lum) {
    final back = Semantics(
      button: true,
      label: _selectionMode ? 'Cancel selection' : 'Back',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _selectionMode
            ? _toggleSelectionMode
            : () => Navigator.of(context).maybePop(),
        child: ClayContainer(
          variant: ClayVariant.soft,
          color: lum.surface,
          borderRadius: AppRadius.sm,
          isDark: lum.isDark,
          width: 44,
          height: 44,
          child: Icon(
            _selectionMode ? LucideIcons.x : LucideIcons.arrowLeft,
            size: 20,
            color: lum.g600,
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          back,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'INVENTORY',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.7,
                    color: lum.g400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _selectionMode
                      ? '${_selectedIds.length} selected'
                      : 'Products',
                  style: AppTypography.title1
                      .copyWith(fontSize: 23, color: lum.textPrimary),
                ),
              ],
            ),
          ),
          if (!_selectionMode) ...[
            PermissionGate(
              module: 'inventory',
              action: 'export',
              child: _ToolIcon(
                icon: LucideIcons.printer,
                tooltip: 'Print labels',
                onTap: _toggleSelectionMode,
              ),
            ),
            const SizedBox(width: 8),
            PermissionGate(
              module: 'inventory',
              action: 'create',
              child: _ToolIcon(
                icon: LucideIcons.upload,
                tooltip: 'Import products',
                onTap: () => context.push('/inventory/import'),
              ),
            ),
            const SizedBox(width: 8),
            PermissionGate(
              module: 'inventory',
              action: 'create',
              child: AppButton(
                label: 'Add',
                icon: LucideIcons.plus,
                size: AppButtonSize.sm,
                onPressed: () => context.push('/inventory/products/create'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(AsyncValue<List<Product>> state) {
    return state.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: AppListSkeleton(),
      ),
      error: (e, _) => AppErrorState(
        title: "We couldn't load products",
        body: 'We couldn\'t reach the server. Your data is safe — '
            'try again in a moment.',
        onRetry: _applyFilters,
      ),
      data: (products) {
        if (products.isEmpty) {
          return AppEmptyState(
            icon: _isSearching ? LucideIcons.searchX : LucideIcons.boxes,
            title: _isSearching ? 'No products match' : 'No products yet',
            body: _isSearching
                ? 'Try a different search term or clear filters.'
                : 'Your catalog is empty. Add your first product to '
                    'start selling.',
            action: _isSearching
                ? null
                : PermissionGate(
                    module: 'inventory',
                    action: 'create',
                    child: AppButton(
                      label: 'Add product',
                      icon: LucideIcons.plus,
                      onPressed: () =>
                          context.push('/inventory/products/create'),
                    ),
                  ),
          );
        }
        return ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(
              16, 4, 16, _selectionMode && _selectedIds.isNotEmpty ? 96 : 24),
          itemCount: products.length + (_loadingMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (i >= products.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final p = products[i];
            return Padding(
              padding: EdgeInsets.only(bottom: i < products.length - 1 ? 10 : 0),
              child: _ProductCard(
                product: p,
                selectionMode: _selectionMode,
                selected: _selectedIds.contains(p.id),
                onToggle: _selectionMode ? () => _toggleProduct(p.id) : null,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSelectionBar(LumColors lum) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClayContainer(
          variant: ClayVariant.raised,
          color: lum.ink,
          borderRadius: AppRadius.lg,
          isDark: lum.isDark,
          padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
          child: Row(
            children: [
              Text(
                '${_selectedIds.length} item${_selectedIds.length == 1 ? '' : 's'}',
                style: AppTypography.headline.copyWith(color: lum.paper),
              ),
              const Spacer(),
              AppButton(
                label: 'Choose template',
                icon: LucideIcons.arrowRight,
                size: AppButtonSize.sm,
                onPressed: () => context.push('/inventory/labels',
                    extra: _selectedIds.toList()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  const _ToolIcon({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Tooltip(
      message: tooltip ?? '',
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ClayContainer(
            variant: ClayVariant.soft,
            color: active ? lum.accentSoft : lum.surface,
            borderRadius: AppRadius.sm,
            isDark: lum.isDark,
            width: 44,
            height: 44,
            child: Icon(icon,
                size: 19, color: active ? lum.accentPress : lum.g600),
          ),
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
  final void Function({String? categoryId, String? brandId, String? status})
      onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _DropdownChip(
            label: selectedCategoryId != null
                ? categories
                        .where((c) => c.id == selectedCategoryId)
                        .firstOrNull
                        ?.name ??
                    'Category'
                : 'Category',
            active: selectedCategoryId != null,
            onClear: selectedCategoryId != null
                ? () => onChanged(
                    categoryId: null,
                    brandId: selectedBrandId,
                    status: selectedStatus)
                : null,
            onTap: () => _showCategoryPicker(context),
          ),
          _DropdownChip(
            label: selectedBrandId != null
                ? brands
                        .where((b) => b.id == selectedBrandId)
                        .firstOrNull
                        ?.name ??
                    'Brand'
                : 'Brand',
            active: selectedBrandId != null,
            onClear: selectedBrandId != null
                ? () => onChanged(
                    categoryId: selectedCategoryId,
                    brandId: null,
                    status: selectedStatus)
                : null,
            onTap: () => _showBrandPicker(context),
          ),
          _DropdownChip(
            label: _statusLabel(selectedStatus),
            active: selectedStatus != null,
            onClear: selectedStatus != null
                ? () => onChanged(
                    categoryId: selectedCategoryId,
                    brandId: selectedBrandId,
                    status: null)
                : null,
            onTap: () => _showStatusPicker(context),
          ),
        ],
      ),
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
    showAppSheet<void>(
      context: context,
      builder: (ctx) => _PickerSheet(
        title: 'Category',
        allLabel: 'All categories',
        onAll: () {
          Navigator.of(ctx).pop();
          onChanged(
              categoryId: null,
              brandId: selectedBrandId,
              status: selectedStatus);
        },
        options: [
          for (final c in categories)
            _PickerOption(
              label: c.name,
              selected: c.id == selectedCategoryId,
              onTap: () {
                Navigator.of(ctx).pop();
                onChanged(
                    categoryId: c.id,
                    brandId: selectedBrandId,
                    status: selectedStatus);
              },
            ),
        ],
      ),
    );
  }

  void _showBrandPicker(BuildContext context) {
    showAppSheet<void>(
      context: context,
      builder: (ctx) => _PickerSheet(
        title: 'Brand',
        allLabel: 'All brands',
        onAll: () {
          Navigator.of(ctx).pop();
          onChanged(
              categoryId: selectedCategoryId,
              brandId: null,
              status: selectedStatus);
        },
        options: [
          for (final b in brands)
            _PickerOption(
              label: b.name,
              selected: b.id == selectedBrandId,
              onTap: () {
                Navigator.of(ctx).pop();
                onChanged(
                    categoryId: selectedCategoryId,
                    brandId: b.id,
                    status: selectedStatus);
              },
            ),
        ],
      ),
    );
  }

  void _showStatusPicker(BuildContext context) {
    showAppSheet<void>(
      context: context,
      builder: (ctx) => _PickerSheet(
        title: 'Status',
        allLabel: 'All',
        onAll: () {
          Navigator.of(ctx).pop();
          onChanged(
              categoryId: selectedCategoryId,
              brandId: selectedBrandId,
              status: null);
        },
        options: [
          for (final s in const ['ACTIVE', 'INACTIVE', 'DISCONTINUED'])
            _PickerOption(
              label: _statusLabel(s),
              selected: s == selectedStatus,
              onTap: () {
                Navigator.of(ctx).pop();
                onChanged(
                    categoryId: selectedCategoryId,
                    brandId: selectedBrandId,
                    status: s);
              },
            ),
        ],
      ),
    );
  }
}

class _PickerOption {
  const _PickerOption(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
}

class _PickerSheet extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.allLabel,
    required this.onAll,
    required this.options,
  });

  final String title;
  final String allLabel;
  final VoidCallback onAll;
  final List<_PickerOption> options;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    Widget row(String label, bool selected, VoidCallback onTap) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.body.copyWith(
                      color: lum.textPrimary,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (selected)
                  Icon(LucideIcons.check, size: 18, color: lum.accent),
              ],
            ),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSheetHeader(title: title),
        row(allLabel, options.every((o) => !o.selected), onAll),
        for (final o in options) row(o.label, o.selected, o.onTap),
        const SizedBox(height: 8),
      ],
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
    final lum = context.lum;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ClayContainer(
        variant: ClayVariant.soft,
        color: active ? lum.accentSoft : lum.surface,
        borderRadius: AppRadius.pill,
        isDark: lum.isDark,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.footnote.copyWith(
                fontWeight: FontWeight.w600,
                color: active ? lum.accentPress : lum.g600,
              ),
            ),
            const SizedBox(width: 4),
            if (active && onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(LucideIcons.x, size: 15, color: lum.accentPress),
              )
            else
              Icon(LucideIcons.chevronDown, size: 15, color: lum.g500),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({
    required this.product,
    required this.selectionMode,
    this.selected = false,
    this.onToggle,
  });

  final Product product;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final brands = ref.watch(brandsProvider).value ?? <Brand>[];
    final brandName =
        brands.where((b) => b.id == product.brandId).firstOrNull?.name;
    final (tone, label) =
        stockStatusPill(product.qtyOnHand, product.reorderPoint, product.type);

    return AppCard(
      onTap: selectionMode
          ? onToggle
          : () => context.push('/inventory/stock/${product.id}'),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          if (selectionMode) ...[
            AppCheckbox(
              value: selected,
              onChanged: (_) => onToggle?.call(),
            ),
            const SizedBox(width: 12),
          ],
          ClayContainer(
            variant: ClayVariant.inset,
            color: lum.g100,
            borderRadius: AppRadius.sm,
            isDark: lum.isDark,
            width: 46,
            height: 46,
            child: Icon(kInvItemIcon, size: 21, color: lum.g500),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppTypography.headline.copyWith(color: lum.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  _meta(brandName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption
                      .copyWith(color: lum.g500, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppMoneyText(product.sellingPrice, size: 16),
              const SizedBox(height: 6),
              AppPill(label: label, tone: tone),
            ],
          ),
        ],
      ),
    );
  }

  String _meta(String? brandName) {
    final parts = <String>[
      product.sku,
      if (brandName != null && brandName.isNotEmpty) brandName,
      productTypeLabel(product.type),
    ];
    return parts.join(' · ');
  }
}
