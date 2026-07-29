import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../../sales/presentation/widgets/scanned_product_dialog.dart';
import '../../domain/entities/brand.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/stock_balance.dart';
import '../../domain/entities/stock_ledger_entry.dart';
import '../../domain/entities/stock_movement_type.dart';
import '../../domain/entities/warehouse.dart';
import '../../domain/entities/product_variant.dart';
import '../../domain/entities/pricing_tier.dart';
import '../../domain/usecases/get_product.dart';
import '../../domain/usecases/load_stock_balances.dart';
import '../../domain/usecases/load_product_ledger.dart';
import '../../domain/usecases/load_variants.dart';
import '../../domain/usecases/load_pricing_tiers.dart';
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
  List<ProductVariant>? _variants;
  List<PricingTier>? _tiers;

  /// Set when the product is not in the loaded products list (scan or deep
  /// link lands on a product outside the current page/filter).
  Product? _fetched;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _balances = null;
      _ledger = null;
      _variants = null;
      _tiers = null;
      _error = null;
    });

    // productsProvider only holds the current page/filter, so a scanned product
    // can be missing from it — fetch it by id rather than spinning forever.
    final listed = (ref.read(productsProvider).value ?? const <Product>[])
        .any((p) => p.id == widget.productId);
    if (!listed && _fetched == null) {
      final (fetched, fail) =
          await ref.read(getProductUseCaseProvider).call(widget.productId);
      if (!mounted) return;
      if (fetched == null) {
        setState(() => _error = fail?.message ?? 'Product not found.');
        return;
      }
      setState(() => _fetched = fetched);
    }

    final branch = ref.read(currentBranchProvider);
    if (branch == null) {
      setState(() => _error = 'No branch selected. Pick a branch and retry.');
      return;
    }

    final (bals, balFail) = await ref.read(loadStockBalancesUseCaseProvider).call(
          branchId: branch.id,
          productId: widget.productId,
        );
    final (ledger, ledFail) =
        await ref.read(loadProductLedgerUseCaseProvider).call(
              widget.productId,
              branchId: branch.id,
            );
    // Variants + pricing tiers are secondary — a failure here leaves them empty
    // rather than blocking the whole page.
    final (variants, _) =
        await ref.read(loadVariantsUseCaseProvider).call(widget.productId);
    final (tiers, _) =
        await ref.read(loadPricingTiersUseCaseProvider).call(widget.productId);

    if (!mounted) return;

    if (balFail != null || ledFail != null) {
      setState(() => _error = (balFail ?? ledFail)!.message);
      return;
    }

    setState(() {
      _balances = bals;
      _ledger = ledger;
      _variants = variants;
      _tiers = tiers;
    });
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider).value ?? <Product>[];
    final product =
        products.where((p) => p.id == widget.productId).firstOrNull ?? _fetched;
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
        title: "Unable to load stock",
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
    final tiers = (_tiers ?? []).where((t) => t.isActive).toList();
    final variants = (_variants ?? []).where((v) => v.isActive).toList();

    // Ledger roll-up shown in the header strip; detail stays in the card below.
    final entries = _ledger ?? const <StockLedgerEntry>[];
    var opening = 0.0, stockIn = 0.0, stockOut = 0.0;
    for (final e in entries) {
      if (e.operationType == StockMovementType.openingBalance) {
        opening += e.qtyChange;
      } else if (e.qtyChange >= 0) {
        stockIn += e.qtyChange;
      } else {
        stockOut += -e.qtyChange;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderCard(
          product: product,
          categories: categories,
          brands: brands,
          totalOnHand: totalOnHand,
          opening: opening,
          stockIn: stockIn,
          stockOut: stockOut,
          onEdit: () => context.push('/inventory/products/${product.id}'),
          onAddToCart: () {
            final added = addProductToCart(ref, product);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(added
                  ? 'Added ${product.name} to cart'
                  : 'Tax settings are still loading. Try again in a moment.'),
            ));
          },
          onAdjust: () => context.push('/inventory/adjustments/create'),
          onOpening: () => context.push('/inventory/stock/movement',
              extra: {'productId': widget.productId}),
          onPrint: () => context.push('/inventory/labels',
              extra: <String>[widget.productId]),
        ),
        const SizedBox(height: 16),
        if (variants.isNotEmpty) ...[
          _VariantsCard(variants: variants),
          const SizedBox(height: 16),
        ],
        if (tiers.isNotEmpty) ...[
          _PricingTiersCard(tiers: tiers),
          const SizedBox(height: 16),
        ],
        _StockTrendCard(
          ledger: _ledger,
          reorderPoint: product.reorderPoint,
          current: totalOnHand,
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
    required this.opening,
    required this.stockIn,
    required this.stockOut,
    required this.onEdit,
    required this.onAddToCart,
    required this.onAdjust,
    required this.onOpening,
    required this.onPrint,
  });

  final Product product;
  final List<Category> categories;
  final List<Brand> brands;
  final double totalOnHand;
  final double opening;
  final double stockIn;
  final double stockOut;
  final VoidCallback onEdit;
  final VoidCallback onAddToCart;
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

    Widget qty(double v, Color color) => Text(qtyLabel(v),
        style: AppTypography.monoValue.copyWith(fontSize: 16, color: color));

    final specs = <_SpecCell>[
      _SpecCell('Cost', AppMoneyText(product.costPrice, size: 16)),
      _SpecCell(
        'Margin',
        Text(margin == null ? '—' : '${margin.toStringAsFixed(0)}%',
            style: AppTypography.monoValue.copyWith(
                fontSize: 16,
                color: margin == null ? lum.g400 : lum.successText)),
      ),
      _SpecCell('Reorder at', qty(product.reorderPoint.toDouble(), lum.textPrimary)),
      _SpecCell('Opening qty', qty(opening, opening == 0 ? lum.g400 : lum.textPrimary)),
      _SpecCell('Stock in', qty(stockIn, stockIn == 0 ? lum.g400 : lum.successText)),
      _SpecCell('Stock out', qty(stockOut, stockOut == 0 ? lum.g400 : lum.dangerText)),
      _SpecCell('Current', qty(totalOnHand, lum.textPrimary)),
    ];

    return AppCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 560;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _hero(context, wide, meta, label, tone),
              const SizedBox(height: AppSpacing.xl),
              _SpecStrip(specs: specs, wide: wide),
              const SizedBox(height: AppSpacing.lg),
              Divider(height: 1, thickness: 1, color: lum.hairline),
              const SizedBox(height: AppSpacing.base),
              _actions(wide),
            ],
          );
        },
      ),
    );
  }

  Widget _image(BuildContext context, double size) {
    final lum = context.lum;
    return ClayContainer(
      variant: ClayVariant.inset,
      color: lum.g100,
      borderRadius: AppRadius.lg,
      isDark: lum.isDark,
      width: size,
      height: size,
      child: product.imageUrl == null
          ? Icon(kInvItemIcon, size: size * 0.42, color: lum.g400)
          : ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Image.network(
                product.imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.fill,
                errorBuilder: (_, _, _) =>
                    Icon(kInvItemIcon, size: size * 0.42, color: lum.g400),
              ),
            ),
    );
  }

  Widget _identity(BuildContext context, String meta, bool wide) {
    final lum = context.lum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(product.name,
            style: (wide ? AppTypography.title2 : AppTypography.title3)
                .copyWith(color: lum.textPrimary, height: 1.12)),
        const SizedBox(height: 6),
        Text(meta, style: AppTypography.footnote.copyWith(color: lum.g500)),
        const SizedBox(height: 10),
        _skuChip(context),
      ],
    );
  }

  Widget _skuChip(BuildContext context) {
    final lum = context.lum;
    final hasBarcode = product.barcode != null && product.barcode!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: lum.g100,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.scanLine, size: 13, color: lum.g500),
          const SizedBox(width: 6),
          Text(
            hasBarcode ? '${product.sku}  ·  ${product.barcode}' : product.sku,
            style: AppTypography.monoValue.copyWith(fontSize: 12, color: lum.g600),
          ),
        ],
      ),
    );
  }

  Widget _priceBlock(BuildContext context, String label, AppPillTone tone,
      {required bool end}) {
    return Column(
      crossAxisAlignment:
          end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppMoneyText(product.sellingPrice, size: 30),
        const SizedBox(height: 8),
        AppPill(label: label, tone: tone),
      ],
    );
  }

  Widget _hero(BuildContext context, bool wide, String meta, String label,
      AppPillTone tone) {
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _image(context, 120),
          const SizedBox(width: 20),
          Expanded(child: _identity(context, meta, true)),
          const SizedBox(width: 16),
          _priceBlock(context, label, tone, end: true),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _image(context, 92),
            const SizedBox(width: 16),
            Expanded(child: _identity(context, meta, false)),
          ],
        ),
        const SizedBox(height: AppSpacing.base),
        _priceBlock(context, label, tone, end: false),
      ],
    );
  }

  Widget _actions(bool wide) {
    // Five actions no longer fit a fixed row: compact size on wide, and a Wrap
    // instead of a Row so the tail flows to a second line rather than overflowing.
    final size = wide ? AppButtonSize.sm : AppButtonSize.md;
    final edit = AppButton(
        label: 'Edit', icon: LucideIcons.pencil, size: size, onPressed: onEdit);
    // Hidden for staff without sales:create.
    final addToCart = PermissionGate(
      module: 'sales',
      action: 'create',
      child: Padding(
        padding: EdgeInsets.only(top: wide ? 0 : 10),
        child: AppButton(
            label: 'Add to cart',
            icon: LucideIcons.shoppingCart,
            variant: AppButtonVariant.tinted,
            fullWidth: !wide,
            size: size,
            onPressed: onAddToCart),
      ),
    );
    final adjust = AppButton(
        label: 'Adjust stock',
        icon: LucideIcons.slidersHorizontal,
        variant: AppButtonVariant.tinted,
        size: size,
        onPressed: onAdjust);
    final opening = AppButton(
        label: 'Set opening stock',
        icon: LucideIcons.packagePlus,
        variant: AppButtonVariant.plain,
        size: size,
        onPressed: onOpening);
    final print = AppButton(
        label: 'Print label',
        icon: LucideIcons.printer,
        variant: AppButtonVariant.plain,
        size: size,
        onPressed: onPrint);

    if (wide) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [edit, adjust, addToCart, opening, print],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
            label: 'Edit',
            icon: LucideIcons.pencil,
            fullWidth: true,
            onPressed: onEdit),
        addToCart,
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: adjust),
        ]),
        const SizedBox(height: 4),
        // Wrap, not Row: at md size these two exceed a narrow phone width.
        Wrap(spacing: 8, runSpacing: 8, children: [opening, print]),
      ],
    );
  }
}

class _SpecCell {
  const _SpecCell(this.label, this.value);
  final String label;
  final Widget value;
}

/// Apple-style spec strip: label/value pairs split by hairline dividers.
/// One row on wide, a 2x2 grid on narrow.
class _SpecStrip extends StatelessWidget {
  const _SpecStrip({required this.specs, required this.wide});

  final List<_SpecCell> specs;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    Widget cell(_SpecCell s) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.label.toUpperCase(),
                style: AppTypography.caption.copyWith(
                    color: lum.g500,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4)),
            const SizedBox(height: 7),
            s.value,
          ],
        );
    Widget vDivider() =>
        Container(width: 1, height: 34, color: lum.hairline);

    final container = BoxDecoration(
      color: lum.g100.withValues(alpha: lum.isDark ? 1 : 0.55),
      borderRadius: BorderRadius.circular(AppRadius.md),
    );

    // Chunk into rows so any number of specs lays out: 4 per row wide, 2 narrow.
    final perRow = wide ? 4 : 2;
    final rows = [
      for (var i = 0; i < specs.length; i += perRow)
        specs.sublist(i, math.min(i + perRow, specs.length)),
    ];

    Widget rowOf(List<_SpecCell> r) => IntrinsicHeight(
          child: Row(
            children: [
              for (var i = 0; i < perRow; i++) ...[
                Expanded(
                    child: i < r.length ? cell(r[i]) : const SizedBox.shrink()),
                // No trailing divider, and none before a padding slot.
                if (i < perRow - 1 && i + 1 < r.length) vDivider(),
              ],
            ],
          ),
        );

    return Container(
      decoration: container,
      padding: EdgeInsets.symmetric(horizontal: wide ? 20 : 18, vertical: 16),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 14),
              Divider(height: 1, thickness: 1, color: lum.hairline),
              const SizedBox(height: 14),
            ],
            rowOf(rows[i]),
          ],
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
          _sectionHeader(context, LucideIcons.warehouse, 'On hand by warehouse'),
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
          _sectionHeader(context, LucideIcons.history, 'Detailed ledger'),
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

/// Minimal stock-level trend: cumulative on-hand over the ledger, drawn as a
/// filled sparkline with a dashed reorder reference line. No chart dependency.
class _StockTrendCard extends StatelessWidget {
  const _StockTrendCard({
    required this.ledger,
    required this.reorderPoint,
    required this.current,
  });

  final List<StockLedgerEntry>? ledger;
  final int reorderPoint;
  final double current;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    // Ledger is newest-first; walk oldest-first to build the running balance.
    var series = const <double>[];
    if (ledger != null && ledger!.isNotEmpty) {
      final asc = ledger!.reversed.toList();
      var running = 0.0;
      series = [for (final e in asc) running += e.qtyChange];
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, LucideIcons.trendingUp, 'Stock trend'),
          if (ledger == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (series.length < 2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Not enough movement history to chart yet.',
                  style: AppTypography.footnote.copyWith(color: lum.g400)),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('ON HAND NOW',
                        style: AppTypography.caption.copyWith(
                            color: lum.g500,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4)),
                    const SizedBox(height: 4),
                    Text(qtyLabel(current),
                        style: AppTypography.monoValue
                            .copyWith(fontSize: 22, color: lum.textPrimary)),
                  ],
                ),
                const Spacer(),
                _reorderChip(context),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 72,
              width: double.infinity,
              child: CustomPaint(
                painter: _SparklinePainter(
                  values: series,
                  reorder: reorderPoint.toDouble(),
                  line: lum.accent,
                  fill: lum.accentSoft,
                  reorderColor: lum.warning,
                  dot: lum.surface,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _reorderChip(BuildContext context) {
    final lum = context.lum;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: lum.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.flag, size: 12, color: lum.warningText),
          const SizedBox(width: 6),
          Text('Reorder at $reorderPoint',
              style: AppTypography.caption.copyWith(
                  color: lum.warningText, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.reorder,
    required this.line,
    required this.fill,
    required this.reorderColor,
    required this.dot,
  });

  final List<double> values;
  final double reorder;
  final Color line;
  final Color fill;
  final Color reorderColor;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = [...values, reorder, 0.0].reduce(math.max);
    final minV = [...values, reorder, 0.0].reduce(math.min);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : maxV - minV;
    final dx = size.width / (values.length - 1);
    double y(double v) => size.height - ((v - minV) / range) * size.height;

    // Dashed reorder reference line.
    if (reorder >= minV && reorder <= maxV) {
      final ry = y(reorder);
      final p = Paint()
        ..color = reorderColor.withValues(alpha: 0.6)
        ..strokeWidth = 1;
      const dash = 5.0, gap = 4.0;
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(
            Offset(x, ry), Offset(math.min(x + dash, size.width), ry), p);
        x += dash + gap;
      }
    }

    final path = Path();
    final area = Path();
    for (var i = 0; i < values.length; i++) {
      final px = dx * i;
      final py = y(values[i]);
      if (i == 0) {
        path.moveTo(px, py);
        area.moveTo(px, size.height);
        area.lineTo(px, py);
      } else {
        path.lineTo(px, py);
        area.lineTo(px, py);
      }
    }
    area.lineTo(dx * (values.length - 1), size.height);
    area.close();
    canvas.drawPath(area, Paint()..color = fill..style = PaintingStyle.fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    final last = Offset(dx * (values.length - 1), y(values.last));
    canvas.drawCircle(last, 3.5, Paint()..color = line);
    canvas.drawCircle(
        last,
        3.5,
        Paint()
          ..color = dot
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values || old.reorder != reorder;
}

/// Active variants for the product — name, SKU + attributes, and selling price.
class _VariantsCard extends StatelessWidget {
  const _VariantsCard({required this.variants});

  final List<ProductVariant> variants;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, LucideIcons.layers, 'Variants'),
          for (int i = 0; i < variants.length; i++)
            _row(context, variants[i], showTop: i > 0),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, ProductVariant v, {required bool showTop}) {
    final lum = context.lum;
    final attrs = v.attributes.values
        .map((x) => '$x')
        .where((s) => s.trim().isNotEmpty)
        .join(' · ');
    final meta = [v.sku, if (attrs.isNotEmpty) attrs].join(' · ');
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
                Text(v.variantName,
                    style: AppTypography.body.copyWith(
                        color: lum.textPrimary, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(color: lum.g500)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AppMoneyText(v.sellingPrice, size: 15),
        ],
      ),
    );
  }
}

/// Quantity-break pricing tiers — tier name, qty range (+ discount), unit price.
class _PricingTiersCard extends StatelessWidget {
  const _PricingTiersCard({required this.tiers});

  final List<PricingTier> tiers;

  @override
  Widget build(BuildContext context) {
    // Ascending min-qty reads like a price ladder.
    final sorted = [...tiers]..sort((a, b) => a.minQty.compareTo(b.minQty));
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, LucideIcons.tags, 'Pricing tiers'),
          for (int i = 0; i < sorted.length; i++)
            _row(context, sorted[i], showTop: i > 0),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, PricingTier t, {required bool showTop}) {
    final lum = context.lum;
    final qty = t.maxQty != null ? '${t.minQty}–${t.maxQty}' : '${t.minQty}+';
    final discount =
        t.discountPct != null ? ' · ${_pct(t.discountPct!)} off' : '';
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
                Text(t.tierName,
                    style: AppTypography.body.copyWith(
                        color: lum.textPrimary, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('Qty $qty$discount',
                    style: AppTypography.caption.copyWith(color: lum.g500)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AppMoneyText(t.unitPrice, size: 15),
        ],
      ),
    );
  }

  String _pct(double p) =>
      '${p.toStringAsFixed(p.truncateToDouble() == p ? 0 : 1)}%';
}

Widget _sectionHeader(BuildContext context, IconData icon, String title) {
  final lum = context.lum;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 17, color: lum.g500),
          const SizedBox(width: 8),
          Text(title,
              style: AppTypography.headline.copyWith(color: lum.textPrimary)),
        ],
      ),
      const SizedBox(height: 12),
      Divider(height: 1, thickness: 1, color: lum.hairline),
      const SizedBox(height: 8),
    ],
  );
}
