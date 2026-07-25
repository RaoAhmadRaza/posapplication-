import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../../core/design/app_colors.dart';
import '../../../../../core/design/app_radius.dart';
import '../../../../../core/design/app_typography.dart';
import '../../../../../core/design/clay.dart';
import '../../../../../core/design/widgets/app_money_text.dart';
import '../../../../inventory/domain/entities/product.dart';
import '../../../../inventory/domain/entities/stock_level.dart';

/// Minimum tile width; the grid fits as many whole columns as that allows.
const _kMinTileWidth = 158.0;
const _kGridGap = 12.0;

// Every row of a tile is pinned to an explicit height, so the tile's total is
// arithmetic rather than a guess. Change a row here and change its constant —
// nothing else in the file needs touching.
const _kSlotHeight = 64.0; // placeholder image slot
const _kSlotGap = 11.0;
const _kNameHeight = 36.0; // 2 lines x 18 (13.5pt at height 1.3)
const _kSkuHeight = 14.0; // 1 line, 10.5pt at height 1.3
const _kPriceGap = 4.0;
const _kPriceHeight = 20.0; // AppMoneyText at size 15
const _kStockGap = 2.0;
const _kStockHeight = 15.0; // 1 line, 11pt at height 1.3
const _kTilePadding = 14.0;

/// Rows whose height is text and therefore grows with the OS text scale.
const _kTextRows =
    _kNameHeight + _kSkuHeight + _kPriceHeight + _kStockHeight;

/// Rows that are fixed no matter the text scale.
const _kChromeRows =
    _kSlotHeight + _kSlotGap + _kPriceGap + _kStockGap + _kTilePadding * 2;

/// Total tile height at the given text scale. The grid derives its aspect ratio
/// from this against the measured cell width, so the ratio is never hand-picked
/// (no dead space) and a user with larger type does not overflow the tile.
double _tileHeight(BuildContext context) =>
    _kChromeRows + _kTextRows * MediaQuery.textScalerOf(context).scale(1);

/// The design's product catalogue: a card grid of parts, tapped to add to cart.
class ProductGrid extends StatelessWidget {
  const ProductGrid({
    super.key,
    required this.products,
    required this.stockMap,
    required this.cartQtyOf,
    required this.onAdd,
    required this.online,
    this.scrollController,
    this.padding = const EdgeInsets.fromLTRB(18, 0, 18, 18),
  });

  final List<Product> products;
  final Map<String, StockLevel> stockMap;
  final ScrollController? scrollController;

  /// Quantity of a product already in the cart, for the corner badge.
  final double Function(String productId) cartQtyOf;
  final void Function(Product) onAdd;

  /// Decides how a missing stock level reads — see [ProductTile].
  final bool online;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - padding.horizontal;
        final cols = ((available + _kGridGap) / (_kMinTileWidth + _kGridGap))
            .floor()
            .clamp(2, 8);
        final cellWidth = (available - _kGridGap * (cols - 1)) / cols;
        final tileHeight = _tileHeight(context);

        return GridView.builder(
          controller: scrollController,
          padding: padding,
          itemCount: products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: _kGridGap,
            crossAxisSpacing: _kGridGap,
            childAspectRatio: cellWidth / tileHeight,
          ),
          itemBuilder: (context, i) {
            final product = products[i];
            final stock = stockMap[product.id];
            return ProductTile(
              product: product,
              stock: stock,
              cartQty: cartQtyOf(product.id),
              online: online,
              onTap: () => onAdd(product),
            );
          },
        );
      },
    );
  }
}

/// One catalogue tile. Out-of-stock tiles dim and stop responding rather than
/// disappearing, so the shelf stays stable while stock moves.
class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    required this.stock,
    required this.cartQty,
    required this.online,
    required this.onTap,
  });

  final Product product;
  final StockLevel? stock;
  final double cartQty;

  /// Online, a missing [stock] level means the product has none on hand.
  /// Offline the stock cache is empty, so the same absence means "unknown".
  final bool online;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final available = stock?.available ?? 0;
    // Online, no stock row means the product genuinely has none on hand.
    // Offline the cache carries no stock at all, so the same absence means
    // "unknown" — and an offline cash sale must still be possible.
    final unknownStock = stock == null && !online;
    final outOfStock = stock == null ? online : available <= 0;
    final lowStock = stock != null &&
        available > 0 &&
        available <= product.reorderPoint;

    final (stockLabel, stockColor) = switch ((unknownStock, outOfStock, lowStock)) {
      (true, _, _) => ('Stock not cached', lum.g500),
      (_, true, _) => ('Out of stock', lum.dangerText),
      (_, _, true) => ('Low · ${available.toStringAsFixed(0)} left', lum.warningText),
      _ => ('In stock · ${available.toStringAsFixed(0)}', lum.successText),
    };

    final tile = ClayContainer(
      variant: ClayVariant.soft,
      color: lum.surface,
      borderRadius: AppRadius.lg,
      isDark: lum.isDark,
      padding: const EdgeInsets.all(_kTilePadding),
      child: Column(
        // stretch, not start — the slot below has no intrinsic width and would
        // otherwise shrink-wrap its icon into a pill.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primary product image if set; otherwise a calm gradient placeholder.
          Container(
            height: _kSlotHeight,
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [lum.g100, lum.g200],
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: product.imageUrl == null
                ? Icon(LucideIcons.cpu, size: 24, color: lum.g300)
                : Image.network(
                    product.imageUrl!,
                    width: double.infinity,
                    height: _kSlotHeight,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Icon(LucideIcons.cpu, size: 24, color: lum.g300),
                  ),
          ),
          const SizedBox(height: _kSlotGap),
          SizedBox(
            height: _kNameHeight,
            child: Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label.copyWith(
                fontSize: 13.5,
                height: 1.3,
                color: lum.textPrimary,
              ),
            ),
          ),
          SizedBox(
            height: _kSkuHeight,
            child: Text(
              product.sku,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.monoValue.copyWith(
                fontSize: 10.5,
                height: 1.3,
                color: lum.g400,
              ),
            ),
          ),
          const SizedBox(height: _kPriceGap),
          SizedBox(
            height: _kPriceHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppMoneyText(product.sellingPrice, size: 15),
            ),
          ),
          const SizedBox(height: _kStockGap),
          SizedBox(
            height: _kStockHeight,
            child: Text(
              stockLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                fontSize: 11,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: stockColor,
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: !outOfStock,
      label: '${product.name}, $stockLabel',
      child: Opacity(
        opacity: outOfStock ? 0.55 : 1,
        child: Stack(
          children: [
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: InkWell(
                onTap: outOfStock ? null : onTap,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: tile,
              ),
            ),
            if (cartQty > 0)
              Positioned(
                top: 8,
                right: 8,
                child: ClayContainer(
                  variant: ClayVariant.lumen,
                  // lumen paints no fill of its own.
                  color: lum.accent,
                  borderRadius: AppRadius.pill,
                  isDark: lum.isDark,
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      cartQty.toStringAsFixed(0),
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
