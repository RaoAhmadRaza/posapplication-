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
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/stock_level.dart';
import '../../domain/entities/warehouse.dart';
import '../controllers/stock_levels_controller.dart';
import '../controllers/warehouses_controller.dart';

class StockLevelsPage extends ConsumerStatefulWidget {
  const StockLevelsPage({super.key});

  @override
  ConsumerState<StockLevelsPage> createState() => _StockLevelsPageState();
}

class _StockLevelsPageState extends ConsumerState<StockLevelsPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _searchText = '';
  bool _lowStockOnly = false;
  String? _selectedWarehouseId;

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
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _searchText = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    final branch = ref.watch(currentBranchProvider);
    final state = ref.watch(stockLevelsProvider);
    final warehousesAsync = ref.watch(warehousesProvider);
    final warehouses = warehousesAsync.value ?? <Warehouse>[];

    if (_selectedWarehouseId == null && warehouses.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final defaultWh = warehouses.where((w) => w.isDefault).firstOrNull;
        setState(() => _selectedWarehouseId = defaultWh?.id ?? warehouses.first.id);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stock Levels', style: AppTypography.headline),
            if (branch != null)
              Text(
                branch.name,
                style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_calendar, color: AppColors.accent),
            tooltip: 'Set Opening Stock',
            onPressed: () => context.push('/inventory/stock/movement'),
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
                  hint: 'Product name or SKU',
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _WarehouseDropdown(
                        warehouses: warehouses,
                        selectedId: _selectedWarehouseId,
                        onChanged: (id) {
                          setState(() => _selectedWarehouseId = id);
                          ref.read(stockLevelsProvider.notifier).load(warehouseId: id);
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _LowStockToggle(
                      value: _lowStockOnly,
                      onChanged: (v) => setState(() => _lowStockOnly = v),
                    ),
                  ],
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

  Widget _buildBody(AsyncValue<List<StockLevel>> state) {
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppInlineBanner(
                message: 'Could not load stock levels.',
                type: BannerType.error,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Retry',
                onPressed: () => ref.read(stockLevelsProvider.notifier).load(
                      warehouseId: _selectedWarehouseId,
                    ),
              ),
            ],
          ),
        ),
      ),
      data: (levels) {
        var filtered = levels;
        if (_searchText.isNotEmpty) {
          filtered = filtered.where((l) =>
              l.productName.toLowerCase().contains(_searchText) ||
              l.productSku.toLowerCase().contains(_searchText)).toList();
        }
        if (_lowStockOnly) {
          filtered = filtered.where((l) => l.isLowStock).toList();
        }

        if (filtered.isEmpty) {
          final hasFilters = _searchText.isNotEmpty || _lowStockOnly;
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasFilters ? Icons.search_off : Icons.inventory_2_outlined,
                    size: 48,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    hasFilters ? 'No matching stock' : 'No stock levels yet',
                    style: AppTypography.subhead.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    hasFilters
                        ? 'Try a different search or clear filters.'
                        : 'Record stock movements to see levels here.',
                    textAlign: TextAlign.center,
                    style: AppTypography.footnote.copyWith(color: AppColors.textHint),
                  ),
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
          itemCount: filtered.length,
          itemBuilder: (_, i) => Padding(
            padding: EdgeInsets.only(
              bottom: i < filtered.length - 1 ? AppSpacing.md : 0,
            ),
            child: _StockLevelCard(level: filtered[i]),
          ),
        );
      },
    );
  }
}

class _WarehouseDropdown extends StatelessWidget {
  const _WarehouseDropdown({
    required this.warehouses,
    required this.selectedId,
    required this.onChanged,
  });

  final List<Warehouse> warehouses;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = warehouses.where((w) => w.id == selectedId).firstOrNull;
    return InkWell(
      onTap: () => _showPicker(context),
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Row(
          children: [
            Icon(Icons.warehouse, size: 16, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                selected?.name ?? 'All Warehouses',
                style: AppTypography.footnote.copyWith(color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.all_inclusive, size: 20),
              title: const Text('All Warehouses'),
              onTap: () {
                Navigator.of(ctx).pop();
                onChanged(null);
              },
            ),
            ...warehouses.where((w) => w.isActive).map((w) => ListTile(
                  leading: const Icon(Icons.warehouse, size: 20),
                  title: Text(w.name),
                  subtitle: Text(w.code, style: AppTypography.caption),
                  trailing: w.isDefault
                      ? const Icon(Icons.star, size: 16, color: AppColors.accent)
                      : null,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onChanged(w.id);
                  },
                )),
          ],
        ),
      ),
    );
  }
}

class _LowStockToggle extends StatelessWidget {
  const _LowStockToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: value ? AppColors.warning.withValues(alpha: 0.12) : AppColors.fieldFill,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: value ? Border.all(color: AppColors.warning, width: 1) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: value ? AppColors.warning : AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Low Stock',
              style: AppTypography.footnote.copyWith(
                color: value ? AppColors.warning : AppColors.textMuted,
                fontWeight: value ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockLevelCard extends ConsumerWidget {
  const _StockLevelCard({required this.level});
  final StockLevel level;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: InkWell(
        onTap: () => context.push('/inventory/stock/${level.productId}'),
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
                        level.productName.isNotEmpty
                            ? level.productName[0].toUpperCase()
                            : '?',
                        style: AppTypography.headline.copyWith(color: AppColors.accent),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                level.productName,
                                style: AppTypography.headline,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (level.isLowStock) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(AppRadius.chip),
                                ),
                                child: Text(
                                  'Low',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'SKU: ${level.productSku}',
                          style: AppTypography.footnote.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: AppColors.separator, height: AppSpacing.xl),
              Row(
                children: [
                  _StockMetric(label: 'On Hand', value: level.qtyOnHand),
                  _StockMetric(label: 'Reserved', value: level.qtyReserved),
                  _StockMetric(label: 'In Transit', value: level.qtyInTransit),
                  _StockMetric(
                    label: 'Available',
                    value: level.available,
                    accent: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockMetric extends StatelessWidget {
  const _StockMetric({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final double value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1),
            style: AppTypography.headline.copyWith(
              color: accent ? AppColors.accent : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.caption.copyWith(color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}
