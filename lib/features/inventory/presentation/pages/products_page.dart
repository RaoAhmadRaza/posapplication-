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
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/services/scanner_support.dart';
import '../../../../core/services/voice_input_service.dart';
import '../../../../core/services/voice_support.dart';
import '../../../../core/services/voxa_stt_service.dart';
import '../../../../core/widgets/barcode_scan_page.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/brand.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/search_products.dart';
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
  // Replaced wholesale on change, never mutated in place: the picker hands the
  // untouched groups straight back, so clear()+addAll() would empty them.
  Set<String> _filterCategoryIds = {};
  Set<String> _filterBrandIds = {};
  Set<String> _filterStatuses = {};
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
        const SnackBar(content: Text('Unable to load more products.')),
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
          categoryIds: _filterCategoryIds.toList(),
          brandIds: _filterBrandIds.toList(),
          statuses: _filterStatuses.toList(),
        );
  }

  void _onFilterChanged({
    required Set<String> categoryIds,
    required Set<String> brandIds,
    required Set<String> statuses,
  }) {
    setState(() {
      _filterCategoryIds = categoryIds;
      _filterBrandIds = brandIds;
      _filterStatuses = statuses;
    });
    _applyFilters();
  }

  Future<void> _scan() async {
    final code = await scanProductCode(context);
    if (!mounted || code == null) return;
    if (code == barcodeNoCodeFoundSentinel) {
      showAppToast(context, 'No barcode or QR found in that image',
          type: BannerType.warning);
      return;
    }
    await _handleScannedCode(code);
  }

  /// Look up a scanned/decoded code and, on a single exact barcode/SKU match,
  /// jump straight to that product (same target as tapping its card).
  /// Otherwise fall back to the normal filtered search.
  Future<void> _handleScannedCode(String code) async {
    final (results, failure) =
        await ref.read(searchProductsUseCaseProvider).call(code);
    if (!mounted) return;

    if (failure == null) {
      final exact =
          results.where((p) => p.barcode == code || p.sku == code).toList();
      if (exact.length == 1) {
        context.push('/inventory/stock/${exact.first.id}');
        return;
      }
    }

    _searchController.text = code;
    setState(() => _isSearching = true);
    _applyFilters();
    if (failure == null && results.isEmpty) {
      showAppToast(context, 'No product matches that code',
          type: BannerType.warning);
    }
  }

  Future<void> _startVoiceSearch() async {
    // Windows/Linux: record → Voxa transcribe on the second tap (no partials).
    if (voiceSearchCloudSupported) {
      if (VoxaStt.instance.isRecording) {
        final text = await VoxaStt.instance.stopAndTranscribe();
        if (!mounted) return;
        setState(() => _voiceListening = false);
        if (text != null) {
          _searchController.text = text;
          setState(() => _isSearching = true);
          _applyFilters();
        } else {
          showAppToast(context, 'Voice service unavailable — is Voxa running?',
              type: BannerType.warning);
        }
        return;
      }
      final ok = await VoxaStt.instance.startRecording();
      if (!mounted) return;
      setState(() => _voiceListening = ok);
      if (!ok) {
        showAppToast(context, 'Microphone permission needed',
            type: BannerType.warning);
      }
      return;
    }
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
                          if (barcodeScanSupported ||
                              barcodeImageScanSupported) ...[
                            const SizedBox(width: 10),
                            _ToolIcon(
                              icon: LucideIcons.scanLine,
                              tooltip: barcodeScanSupported
                                  ? 'Scan product'
                                  : 'Scan product from image',
                              onTap: _scan,
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
                        selectedCategoryIds: _filterCategoryIds,
                        selectedBrandIds: _filterBrandIds,
                        selectedStatuses: _filterStatuses,
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
        title: "Unable to load products",
        body: 'Unable to reach the server. Try again in a moment.',
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
        final bottomPad =
            _selectionMode && _selectedIds.isNotEmpty ? 96.0 : 24.0;
        // Show products that have a photo first, then the rest — stable within
        // each group so the server order is otherwise preserved.
        final ordered = [
          ...products.where((p) => (p.imageUrl ?? '').trim().isNotEmpty),
          ...products.where((p) => (p.imageUrl ?? '').trim().isEmpty),
        ];
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final cols = w < 600 ? 1 : (w < 1040 ? 2 : 3);
            return Column(
              children: [
                Expanded(
                  child: GridView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPad),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisExtent: 158,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: ordered.length,
                    itemBuilder: (_, i) {
                      final p = ordered[i];
                      return _ProductCard(
                        product: p,
                        selectionMode: _selectionMode,
                        selected: _selectedIds.contains(p.id),
                        onToggle:
                            _selectionMode ? () => _toggleProduct(p.id) : null,
                      );
                    },
                  ),
                ),
                if (_loadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
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

const _statusOptions = [
  ('ACTIVE', 'Active'),
  ('INACTIVE', 'Inactive'),
  ('DISCONTINUED', 'Discontinued'),
];

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.categories,
    required this.brands,
    required this.selectedCategoryIds,
    required this.selectedBrandIds,
    required this.selectedStatuses,
    required this.onChanged,
  });

  final List<Category> categories;
  final List<Brand> brands;
  final Set<String> selectedCategoryIds;
  final Set<String> selectedBrandIds;
  final Set<String> selectedStatuses;
  final void Function({
    required Set<String> categoryIds,
    required Set<String> brandIds,
    required Set<String> statuses,
  }) onChanged;

  @override
  Widget build(BuildContext context) {
    final categoryOptions = [for (final c in categories) (c.id, c.name)];
    final brandOptions = [for (final b in brands) (b.id, b.name)];

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _DropdownChip(
            label: _chipLabel('Category', selectedCategoryIds, categoryOptions),
            active: selectedCategoryIds.isNotEmpty,
            onClear: selectedCategoryIds.isNotEmpty
                ? () => _emit(categoryIds: const {})
                : null,
            onTap: () => _pick(
              context,
              title: 'Category',
              allLabel: 'All categories',
              hint: 'Search categories',
              options: categoryOptions,
              selected: selectedCategoryIds,
              apply: (picked) => _emit(categoryIds: picked),
            ),
          ),
          _DropdownChip(
            label: _chipLabel('Brand', selectedBrandIds, brandOptions),
            active: selectedBrandIds.isNotEmpty,
            onClear: selectedBrandIds.isNotEmpty
                ? () => _emit(brandIds: const {})
                : null,
            onTap: () => _pick(
              context,
              title: 'Brand',
              allLabel: 'All brands',
              hint: 'Search brands',
              options: brandOptions,
              selected: selectedBrandIds,
              apply: (picked) => _emit(brandIds: picked),
            ),
          ),
          _DropdownChip(
            label: _chipLabel('Status', selectedStatuses, _statusOptions),
            active: selectedStatuses.isNotEmpty,
            onClear: selectedStatuses.isNotEmpty
                ? () => _emit(statuses: const {})
                : null,
            onTap: () => _pick(
              context,
              title: 'Status',
              allLabel: 'All statuses',
              hint: 'Search statuses',
              options: _statusOptions,
              selected: selectedStatuses,
              apply: (picked) => _emit(statuses: picked),
            ),
          ),
        ],
      ),
    );
  }

  /// Emits all three groups, replacing only the one that changed.
  void _emit({
    Set<String>? categoryIds,
    Set<String>? brandIds,
    Set<String>? statuses,
  }) =>
      onChanged(
        categoryIds: categoryIds ?? selectedCategoryIds,
        brandIds: brandIds ?? selectedBrandIds,
        statuses: statuses ?? selectedStatuses,
      );

  /// One pick → its name; several → "Brand · 3"; none → the group name.
  String _chipLabel(
    String base,
    Set<String> selected,
    List<(String, String)> options,
  ) {
    if (selected.isEmpty) return base;
    if (selected.length == 1) {
      return options.where((o) => o.$1 == selected.first).firstOrNull?.$2 ??
          base;
    }
    return '$base · ${selected.length}';
  }

  Future<void> _pick(
    BuildContext context, {
    required String title,
    required String allLabel,
    required String hint,
    required List<(String, String)> options,
    required Set<String> selected,
    required void Function(Set<String>) apply,
  }) async {
    final picked = await showAppSheet<Set<String>>(
      context: context,
      builder: (_) => _MultiPickerSheet(
        title: title,
        allLabel: allLabel,
        searchHint: hint,
        options: options,
        selected: selected,
      ),
    );
    // Dismissed without applying — leave the filter as it was.
    if (picked == null) return;
    apply(picked);
  }
}

/// Searchable multi-select sheet. Picks are held locally and only handed back
/// on Apply, so toggling five options costs one query instead of five.
class _MultiPickerSheet extends StatefulWidget {
  const _MultiPickerSheet({
    required this.title,
    required this.allLabel,
    required this.searchHint,
    required this.options,
    required this.selected,
  });

  final String title;
  final String allLabel;
  final String searchHint;
  final List<(String, String)> options;
  final Set<String> selected;

  @override
  State<_MultiPickerSheet> createState() => _MultiPickerSheetState();
}

class _MultiPickerSheetState extends State<_MultiPickerSheet> {
  final _search = TextEditingController();
  late final Set<String> _sel = {...widget.selected};

  @override
  void initState() {
    super.initState();
    _search.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _search.removeListener(_onQueryChanged);
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged() => setState(() {});

  void _toggle(String id) => setState(() {
        if (!_sel.remove(id)) _sel.add(id);
      });

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final q = _search.text.trim().toLowerCase();
    final visible = q.isEmpty
        ? widget.options
        : widget.options
            .where((o) => o.$2.toLowerCase().contains(q))
            .toList();

    Widget row(String label, bool selected, VoidCallback onTap) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            child: Row(
              children: [
                AppCheckbox(value: selected, onChanged: (_) => onTap()),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.body.copyWith(
                      color: lum.textPrimary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetHeader(title: widget.title),
        AppSearchField(controller: _search, hint: widget.searchHint),
        const SizedBox(height: 6),
        // Bounded so a long list scrolls inside the sheet instead of growing it.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: visible.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No matches',
                    textAlign: TextAlign.center,
                    style: AppTypography.subhead.copyWith(color: lum.g500),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  // The "all" row only makes sense on the unfiltered list.
                  itemCount: visible.length + (q.isEmpty ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (q.isEmpty && i == 0) {
                      return row(
                        widget.allLabel,
                        _sel.isEmpty,
                        () => setState(_sel.clear),
                      );
                    }
                    final o = visible[q.isEmpty ? i - 1 : i];
                    return row(o.$2, _sel.contains(o.$1), () => _toggle(o.$1));
                  },
                ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              _sel.isEmpty ? 'None selected' : '${_sel.length} selected',
              style: AppTypography.footnote.copyWith(color: lum.g500),
            ),
            const Spacer(),
            AppButton(
              label: 'Apply',
              size: AppButtonSize.sm,
              onPressed: () => Navigator.of(context).pop(_sel),
            ),
          ],
        ),
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

    final photo = ClayContainer(
      variant: ClayVariant.inset,
      color: lum.g100,
      borderRadius: AppRadius.md,
      isDark: lum.isDark,
      width: 116,
      height: 116,
      child: product.imageUrl == null
          ? Icon(kInvItemIcon, size: 40, color: lum.g500)
          : ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.network(
                product.imageUrl!,
                width: 116,
                height: 116,
                fit: BoxFit.fill,
                errorBuilder: (_, _, _) =>
                    Icon(kInvItemIcon, size: 40, color: lum.g500),
              ),
            ),
    );

    return AppCard(
      onTap: selectionMode
          ? onToggle
          : () => context.push('/inventory/stock/${product.id}'),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          selectionMode
              ? Stack(
                  children: [
                    photo,
                    Positioned(
                      top: 4,
                      left: 4,
                      child: AppCheckbox(
                        value: selected,
                        onChanged: (_) => onToggle?.call(),
                      ),
                    ),
                  ],
                )
              : photo,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headline
                          .copyWith(color: lum.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _meta(brandName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption
                          .copyWith(color: lum.g500, fontSize: 12.5),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Cost',
                          style: AppTypography.caption.copyWith(
                            color: lum.g400,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 6),
                        AppMoneyText(product.costPrice,
                            size: 13, color: lum.g500),
                        const Spacer(),
                        AppPill(label: label, tone: tone),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(height: 1, color: lum.g100),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'Sell',
                          style: AppTypography.caption.copyWith(
                            color: lum.g400,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppMoneyText(product.sellingPrice, size: 19),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
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
