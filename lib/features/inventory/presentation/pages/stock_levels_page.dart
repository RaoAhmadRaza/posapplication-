import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_list_skeleton.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_search_field.dart';
import '../../../../core/design/widgets/app_sheet.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/stock_level.dart';
import '../../domain/entities/warehouse.dart';
import '../controllers/stock_levels_controller.dart';
import '../controllers/warehouses_controller.dart';
import '../widgets/inventory_ui.dart';

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

  void _selectWarehouse(String? id) {
    setState(() => _selectedWarehouseId = id);
    ref.read(stockLevelsProvider.notifier).load(warehouseId: id);
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
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

    final selectedWarehouse =
        warehouses.where((w) => w.id == _selectedWarehouseId).firstOrNull;

    return Scaffold(
      backgroundColor: lum.paper,
      body: SafeArea(
        child: Column(
          children: [
            _header(lum, branch?.name),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                children: [
                  AppSearchField(
                    controller: _searchController,
                    hint: 'Search name or SKU',
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _DropdownChip(
                          label: selectedWarehouse?.name ?? 'All warehouses',
                          active: _selectedWarehouseId != null,
                          onClear: _selectedWarehouseId != null
                              ? () => _selectWarehouse(null)
                              : null,
                          onTap: () => _showWarehousePicker(warehouses),
                        ),
                        _ToggleChip(
                          icon: LucideIcons.triangleAlert,
                          label: 'Low stock',
                          active: _lowStockOnly,
                          onTap: () =>
                              setState(() => _lowStockOnly = !_lowStockOnly),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Expanded(child: _buildBody(state)),
          ],
        ),
      ),
    );
  }

  Widget _header(LumColors lum, String? branchName) {
    final back = Semantics(
      button: true,
      label: 'Back',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: ClayContainer(
          variant: ClayVariant.soft,
          color: lum.surface,
          borderRadius: AppRadius.sm,
          isDark: lum.isDark,
          width: 44,
          height: 44,
          child: Icon(LucideIcons.arrowLeft, size: 20, color: lum.g600),
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
                  'Stock levels',
                  style: AppTypography.title1
                      .copyWith(fontSize: 23, color: lum.textPrimary),
                ),
                if (branchName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    branchName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.footnote.copyWith(color: lum.g500),
                  ),
                ],
              ],
            ),
          ),
          _ToolIcon(
            icon: LucideIcons.packagePlus,
            tooltip: 'Set opening stock',
            onTap: () => context.push('/inventory/stock/movement'),
          ),
        ],
      ),
    );
  }

  void _showWarehousePicker(List<Warehouse> warehouses) {
    showAppSheet<void>(
      context: context,
      builder: (ctx) {
        final lum = ctx.lum;
        Widget row(String label, bool selected, VoidCallback onTap) => InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
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
            const AppSheetHeader(title: 'Warehouse'),
            row('All warehouses', _selectedWarehouseId == null, () {
              Navigator.of(ctx).pop();
              _selectWarehouse(null);
            }),
            for (final w in warehouses.where((w) => w.isActive))
              row(w.name, w.id == _selectedWarehouseId, () {
                Navigator.of(ctx).pop();
                _selectWarehouse(w.id);
              }),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildBody(AsyncValue<List<StockLevel>> state) {
    return state.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: AppListSkeleton(),
      ),
      error: (e, _) => AppErrorState(
        title: "Unable to load stock levels",
        body: 'Unable to reach the server. Try again in a moment.',
        onRetry: () => ref
            .read(stockLevelsProvider.notifier)
            .load(warehouseId: _selectedWarehouseId),
      ),
      data: (levels) {
        var filtered = levels;
        if (_searchText.isNotEmpty) {
          filtered = filtered
              .where((l) =>
                  l.productName.toLowerCase().contains(_searchText) ||
                  l.productSku.toLowerCase().contains(_searchText))
              .toList();
        }
        if (_lowStockOnly) {
          filtered =
              filtered.where((l) => l.qtyOnHand <= l.reorderPoint).toList();
        }

        if (filtered.isEmpty) {
          final hasFilters = _searchText.isNotEmpty || _lowStockOnly;
          return AppEmptyState(
            icon: hasFilters ? LucideIcons.searchX : LucideIcons.boxes,
            title: hasFilters ? 'No matching stock' : 'No stock levels yet',
            body: hasFilters
                ? 'Try a different search term or clear filters.'
                : 'Record stock movements to see levels here.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: filtered.length,
          itemBuilder: (_, i) => Padding(
            padding:
                EdgeInsets.only(bottom: i < filtered.length - 1 ? 10 : 0),
            child: _StockLevelCard(level: filtered[i]),
          ),
        );
      },
    );
  }
}

class _ToolIcon extends StatelessWidget {
  const _ToolIcon({required this.icon, required this.onTap, this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

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
            color: lum.surface,
            borderRadius: AppRadius.sm,
            isDark: lum.isDark,
            width: 44,
            height: 44,
            child: Icon(icon, size: 19, color: lum.g600),
          ),
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
    final lum = context.lum;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
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
              Icon(
                LucideIcons.warehouse,
                size: 15,
                color: active ? lum.accentPress : lum.g500,
              ),
              const SizedBox(width: 6),
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
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      button: true,
      toggled: active,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ClayContainer(
          variant: ClayVariant.soft,
          color: active ? lum.warningSoft : lum.surface,
          borderRadius: AppRadius.pill,
          isDark: lum.isDark,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: active ? lum.warningText : lum.g500,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.footnote.copyWith(
                  fontWeight: FontWeight.w600,
                  color: active ? lum.warningText : lum.g600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockLevelCard extends StatelessWidget {
  const _StockLevelCard({required this.level});
  final StockLevel level;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final (tone, label) = stockStatusPill(
      level.qtyOnHand,
      level.reorderPoint,
      ProductType.standard,
    );

    return AppCard(
      onTap: () => context.push('/inventory/stock/${level.productId}'),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
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
                  level.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppTypography.headline.copyWith(color: lum.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  level.productSku,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.monoValue
                      .copyWith(fontSize: 12.5, color: lum.g500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                qtyLabel(level.qtyOnHand),
                style: AppTypography.monoValue.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: lum.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              AppPill(label: label, tone: tone),
            ],
          ),
        ],
      ),
    );
  }
}
