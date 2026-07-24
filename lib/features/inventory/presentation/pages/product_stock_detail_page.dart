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
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/brand.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/stock_balance.dart';
import '../../domain/entities/stock_ledger_entry.dart';
import '../../domain/entities/stock_movement_type.dart';
import '../../domain/entities/warehouse.dart';
import '../../domain/usecases/load_stock_balances.dart';
import '../../domain/usecases/load_product_ledger.dart';
import '../controllers/brands_controller.dart';
import '../controllers/categories_controller.dart';
import '../controllers/warehouses_controller.dart';
import '../controllers/products_controller.dart';
import '../widgets/inventory_ui.dart';

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
    final products = ref.watch(productsProvider).value ?? <Product>[];
    final product = products.where((p) => p.id == widget.productId).firstOrNull;
    final warehouses = ref.watch(warehousesProvider).value ?? <Warehouse>[];
    final categories = ref.watch(categoriesProvider).value ?? <Category>[];
    final brands = ref.watch(brandsProvider).value ?? <Brand>[];

    return AppDetailScaffold(
      eyebrow: 'Inventory',
      title: 'Product',
      maxContentWidth: 760,
      child: _buildChild(product, warehouses, categories, brands),
    );
  }

  Widget _buildChild(
    Product? product,
    List<Warehouse> warehouses,
    List<Category> categories,
    List<Brand> brands,
  ) {
    if (_error != null) {
      return AppErrorState(
        title: "We couldn't load stock",
        body: _error!,
        onRetry: _load,
      );
    }
    if (_balances == null || product == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final totalOnHand =
        _balances!.fold<double>(0, (sum, b) => sum + b.qtyOnHand);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderCard(
          product: product,
          categories: categories,
          brands: brands,
          totalOnHand: totalOnHand,
          onEdit: () => context.push('/inventory/products/${product.id}'),
          onAdjust: () => context.push('/inventory/adjustments/create'),
          onOpening: () => context.push('/inventory/stock/movement',
              extra: {'productId': widget.productId}),
          onPrint: () => context.push('/inventory/labels',
              extra: <String>[widget.productId]),
        ),
        const SizedBox(height: 16),
        _PerWarehouseCard(warehouses: warehouses, balances: _balances!),
        const SizedBox(height: 16),
        _LedgerCard(ledger: _ledger),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.product,
    required this.categories,
    required this.brands,
    required this.totalOnHand,
    required this.onEdit,
    required this.onAdjust,
    required this.onOpening,
    required this.onPrint,
  });

  final Product product;
  final List<Category> categories;
  final List<Brand> brands;
  final double totalOnHand;
  final VoidCallback onEdit;
  final VoidCallback onAdjust;
  final VoidCallback onOpening;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final brandName =
        brands.where((b) => b.id == product.brandId).firstOrNull?.name;
    final catName =
        categories.where((c) => c.id == product.categoryId).firstOrNull?.name;
    final meta = [
      ?brandName,
      ?catName,
      productTypeLabel(product.type),
    ].join(' · ');
    final margin = product.sellingPrice > 0
        ? ((product.sellingPrice - product.costPrice) / product.sellingPrice) *
            100
        : null;
    final (tone, label) =
        stockStatusPill(totalOnHand, product.reorderPoint, product.type);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClayContainer(
                variant: ClayVariant.inset,
                color: lum.g100,
                borderRadius: AppRadius.md,
                isDark: lum.isDark,
                width: 72,
                height: 72,
                child: Icon(kInvItemIcon, size: 32, color: lum.g500),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        style: AppTypography.title2
                            .copyWith(color: lum.textPrimary, height: 1.15)),
                    const SizedBox(height: 5),
                    Text(meta,
                        style: AppTypography.footnote.copyWith(color: lum.g500)),
                    const SizedBox(height: 4),
                    Text(
                      product.barcode != null && product.barcode!.isNotEmpty
                          ? '${product.sku}  ·  ${product.barcode}'
                          : product.sku,
                      style: AppTypography.monoValue
                          .copyWith(fontSize: 12, color: lum.g500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppMoneyText(product.sellingPrice, size: 22),
                  const SizedBox(height: 8),
                  AppPill(label: label, tone: tone),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _statTile(context, 'Cost',
                  child: AppMoneyText(product.costPrice, size: 15)),
              _statTile(context, 'Margin',
                  value: margin == null ? '—' : '${margin.toStringAsFixed(0)}%',
                  color: lum.successText),
              _statTile(context, 'On hand', value: qtyLabel(totalOnHand)),
              _statTile(context, 'Reorder at',
                  value: product.reorderPoint.toString()),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              AppButton(
                  label: 'Edit', icon: LucideIcons.pencil, onPressed: onEdit),
              AppButton(
                  label: 'Adjust stock',
                  icon: LucideIcons.slidersHorizontal,
                  variant: AppButtonVariant.tinted,
                  onPressed: onAdjust),
              AppButton(
                  label: 'Set opening stock',
                  icon: LucideIcons.packagePlus,
                  variant: AppButtonVariant.plain,
                  onPressed: onOpening),
              AppButton(
                  label: 'Print label',
                  icon: LucideIcons.printer,
                  variant: AppButtonVariant.plain,
                  onPressed: onPrint),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(BuildContext context, String label,
      {String? value, Widget? child, Color? color}) {
    final lum = context.lum;
    return Container(
      constraints: const BoxConstraints(minWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: lum.g100,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(),
              style: AppTypography.caption.copyWith(
                  color: lum.g500,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3)),
          const SizedBox(height: 6),
          child ??
              Text(value ?? '—',
                  style: AppTypography.monoValue
                      .copyWith(fontSize: 15, color: color ?? lum.ink)),
        ],
      ),
    );
  }
}

class _PerWarehouseCard extends StatelessWidget {
  const _PerWarehouseCard({required this.warehouses, required this.balances});

  final List<Warehouse> warehouses;
  final List<StockBalance> balances;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final activeWh = warehouses.where((w) => w.isActive).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('On hand by warehouse',
              style: AppTypography.headline.copyWith(color: lum.textPrimary)),
          const SizedBox(height: 6),
          if (activeWh.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No active warehouses.',
                  style: AppTypography.footnote.copyWith(color: lum.g400)),
            )
          else
            for (int i = 0; i < activeWh.length; i++)
              _row(context, activeWh[i], showTop: i > 0),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Warehouse wh, {required bool showTop}) {
    final lum = context.lum;
    final bal = balances.where((b) => b.warehouseId == wh.id).firstOrNull;
    final qty = bal?.qtyOnHand ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: showTop
            ? Border(top: BorderSide(color: lum.hairline))
            : null,
      ),
      child: Row(
        children: [
          if (wh.isDefault) ...[
            Icon(LucideIcons.star, size: 14, color: lum.accent),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(wh.name,
                style: AppTypography.body.copyWith(
                    color: lum.textPrimary, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
          Text(qtyLabel(qty),
              style: AppTypography.monoValue.copyWith(
                  fontSize: 15,
                  color: qty > 0 ? lum.textPrimary : lum.g400)),
        ],
      ),
    );
  }
}

class _LedgerCard extends StatelessWidget {
  const _LedgerCard({required this.ledger});
  final List<StockLedgerEntry>? ledger;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ledger history',
              style: AppTypography.headline.copyWith(color: lum.textPrimary)),
          const SizedBox(height: 6),
          if (ledger == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (ledger!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No stock movements recorded.',
                  style: AppTypography.footnote.copyWith(color: lum.g400)),
            )
          else
            for (int i = 0; i < ledger!.length; i++)
              _row(context, ledger![i], showTop: i > 0),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, StockLedgerEntry e, {required bool showTop}) {
    final lum = context.lum;
    final isPositive = e.qtyChange > 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: showTop ? Border(top: BorderSide(color: lum.hairline)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_opLabel(e.operationType),
                    style: AppTypography.footnote.copyWith(
                        color: lum.textPrimary, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text('${ymd(e.createdAt)} · ${e.referenceType}',
                    style: AppTypography.caption.copyWith(color: lum.g500)),
              ],
            ),
          ),
          Text(
            isPositive
                ? '+${qtyLabel(e.qtyChange)}'
                : qtyLabel(e.qtyChange),
            style: AppTypography.monoValue.copyWith(
                fontSize: 15,
                color: isPositive ? lum.successText : lum.dangerText),
          ),
        ],
      ),
    );
  }

  String _opLabel(StockMovementType t) =>
      t.dbValue.replaceAll('_', ' ').toLowerCase();
}
