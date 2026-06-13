import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/stock_balance.dart';
import '../../domain/entities/stock_ledger_entry.dart';
import '../../domain/entities/stock_movement_type.dart';
import '../../domain/entities/warehouse.dart';
import '../../domain/usecases/load_stock_balances.dart';
import '../../domain/usecases/load_product_ledger.dart';
import '../controllers/warehouses_controller.dart';
import '../controllers/products_controller.dart';
import 'package:go_router/go_router.dart';

class ProductStockDetailPage extends ConsumerStatefulWidget {
  const ProductStockDetailPage({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductStockDetailPage> createState() =>
      _ProductStockDetailPageState();
}

class _ProductStockDetailPageState
    extends ConsumerState<ProductStockDetailPage> {
  List<StockBalance>? _balances;
  List<StockLedgerEntry>? _ledger;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final branch = ref.read(currentBranchProvider);
    if (branch == null) return;

    setState(() {
      _balances = null;
      _ledger = null;
      _error = null;
    });

    final (bals, balFail) = await ref.read(loadStockBalancesUseCaseProvider).call(
          branchId: branch.id,
          productId: widget.productId,
        );
    final (ledger, ledFail) =
        await ref.read(loadProductLedgerUseCaseProvider).call(
              widget.productId,
              branchId: branch.id,
            );

    if (!mounted) return;

    if (balFail != null || ledFail != null) {
      setState(() => _error = (balFail ?? ledFail)!.message);
      return;
    }

    setState(() {
      _balances = bals;
      _ledger = ledger;
    });
  }

  @override
  Widget build(BuildContext context) {
    final branch = ref.watch(currentBranchProvider);
    final products = ref.watch(productsProvider).value ?? [];
    final product = products.where((p) => p.id == widget.productId).firstOrNull;
    final warehouses = ref.watch(warehousesProvider).value ?? <Warehouse>[];

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
            Text(
              product?.name ?? 'Stock Detail',
              style: AppTypography.headline,
              overflow: TextOverflow.ellipsis,
            ),
            if (product != null)
              Text(
                'SKU: ${product.sku}',
                style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_calendar, color: AppColors.accent),
            tooltip: 'Set Opening Stock',
            onPressed: () => context.push('/inventory/stock/movement', extra: {
              'productId': widget.productId,
            }),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppInlineBanner(message: _error!, type: BannerType.error),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : _balances == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPadding,
                      vertical: AppSpacing.md,
                    ),
                    children: [
                      if (branch != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Text(
                            branch.name,
                            style: AppTypography.subhead.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      _PerWarehouseTable(
                        warehouses: warehouses,
                        balances: _balances!,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        'Ledger History',
                        style: AppTypography.subhead.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_ledger == null)
                        const Center(child: CircularProgressIndicator())
                      else if (_ledger!.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xxl,
                            ),
                            child: Text(
                              'No stock movements recorded.',
                              style: AppTypography.footnote.copyWith(
                                color: AppColors.textHint,
                              ),
                            ),
                          ),
                        )
                      else
                        ..._ledger!.map((entry) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: _LedgerEntryCard(entry: entry),
                            )),
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  ),
                ),
    );
  }
}

class _PerWarehouseTable extends StatelessWidget {
  const _PerWarehouseTable({
    required this.warehouses,
    required this.balances,
  });

  final List<Warehouse> warehouses;
  final List<StockBalance> balances;

  @override
  Widget build(BuildContext context) {
    final activeWh = warehouses.where((w) => w.isActive).toList();

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'On Hand by Warehouse',
              style: AppTypography.subhead.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (activeWh.isEmpty)
              Text(
                'No active warehouses.',
                style: AppTypography.footnote.copyWith(color: AppColors.textHint),
              )
            else
              ...activeWh.map((wh) {
                final bal = balances.where((b) => b.warehouseId == wh.id).firstOrNull;
                final qty = bal?.qtyOnHand ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (wh.isDefault)
                              Padding(
                                padding: const EdgeInsets.only(right: AppSpacing.xs),
                                child: Icon(Icons.star, size: 14, color: AppColors.accent),
                              ),
                            Flexible(
                              child: Text(
                                wh.name,
                                style: AppTypography.body,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 1),
                        style: AppTypography.headline.copyWith(
                          color: qty > 0 ? AppColors.success : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _LedgerEntryCard extends StatelessWidget {
  const _LedgerEntryCard({required this.entry});
  final StockLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final isPositive = entry.qtyChange > 0;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.destructive.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Text(
                    entry.operationType.dbValue,
                    style: AppTypography.caption.copyWith(
                      color: isPositive ? AppColors.success : AppColors.destructive,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  isPositive
                      ? '+${entry.qtyChange}'
                      : '${entry.qtyChange}',
                  style: AppTypography.headline.copyWith(
                    color: isPositive ? AppColors.success : AppColors.destructive,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _LedgerDetail(
                  label: 'Balance After',
                  value: entry.balanceAfter.toStringAsFixed(
                    entry.balanceAfter == entry.balanceAfter.roundToDouble()
                        ? 0
                        : 1,
                  ),
                ),
                const SizedBox(width: AppSpacing.xl),
                _LedgerDetail(
                  label: 'Avg Cost',
                  value: entry.avgCostAfter.toStringAsFixed(2),
                ),
                const SizedBox(width: AppSpacing.xl),
                _LedgerDetail(
                  label: 'Ref',
                  value: entry.referenceType,
                ),
              ],
            ),
            if (entry.notes != null && entry.notes!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                entry.notes!,
                style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(
              _formatDate(entry.createdAt),
              style: AppTypography.caption.copyWith(color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _LedgerDetail extends StatelessWidget {
  const _LedgerDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption.copyWith(color: AppColors.textHint)),
        const SizedBox(height: 2),
        Text(value, style: AppTypography.footnote),
      ],
    );
  }
}
