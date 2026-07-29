import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_qty_stepper.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../inventory/domain/entities/product.dart';
import '../../../inventory/presentation/widgets/inventory_ui.dart';
import '../controllers/pos_cart_controller.dart';

/// Adds [qty] units of [product] to the POS cart. A tax-inclusive selling price is
/// split back out so the line stores a net unit price plus its tax pct (cart
/// totals re-add it). Shared by the POS grid and the post-scan dialog.
///
/// The rate is the tenant's, not the product's: create_sale charges the default
/// tax rule on every line whatever the product says, so pricing off
/// `product.taxRate` left the cart short of the invoice. Returns false when the
/// rule has not loaded yet — guessing zero there is what silently under-charges.
bool addProductToCart(WidgetRef ref, Product product, {int qty = 1}) {
  final rate = ref.read(saleTaxRateProvider);
  if (rate == null) return false;
  final price = product.taxInclusive && rate > 0
      ? product.sellingPrice / (1 + rate / 100)
      : product.sellingPrice;
  ref.read(posCartProvider.notifier).addLine(
        productId: product.id,
        productName: product.name,
        sku: product.sku,
        barcode: product.barcode,
        qty: qty.toDouble(),
        unitPrice: price,
        taxPct: rate,
      );
  return true;
}

/// Post-scan product popup shared by Dashboard, POS and Products: shows the
/// matched product's details with a quantity stepper, an "Add to Cart" and a
/// "Back" button. Adds the chosen quantity to the POS cart and returns true
/// when the user adds it; false on Back or dismiss. The add button and stepper
/// are hidden without `sales:create`.
Future<bool> showScannedProductDialog(
  BuildContext context,
  WidgetRef ref,
  Product product,
) async {
  final qty = await showDialog<int>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => _ScannedProductDialog(product: product),
  );
  if (qty != null) return addProductToCart(ref, product, qty: qty);
  return false;
}

class _ScannedProductDialog extends StatefulWidget {
  const _ScannedProductDialog({required this.product});

  final Product product;

  @override
  State<_ScannedProductDialog> createState() => _ScannedProductDialogState();
}

class _ScannedProductDialogState extends State<_ScannedProductDialog> {
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final lum = context.lum;
    final (tone, stockLabel) =
        stockStatusPill(product.qtyOnHand, product.reorderPoint, product.type);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: ClayContainer(
        variant: ClayVariant.raised,
        color: lum.surface,
        borderRadius: AppRadius.xl,
        isDark: lum.isDark,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _photo(lum),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.title3
                            .copyWith(color: lum.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.sku,
                        style: AppTypography.footnote
                            .copyWith(color: lum.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      AppMoneyText(product.sellingPrice, size: 20, decimals: 2),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppPill(label: stockLabel, tone: tone),
                AppPill(
                  label: productTypeLabel(product.type),
                  tone: AppPillTone.neutral,
                  showDot: false,
                ),
              ],
            ),
            if ((product.barcode ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Barcode · ${product.barcode}',
                style:
                    AppTypography.footnote.copyWith(color: lum.textSecondary),
              ),
            ],
            const SizedBox(height: 24),
            PermissionGate(
              module: 'sales',
              action: 'create',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quantity',
                        style: AppTypography.body
                            .copyWith(color: lum.textSecondary),
                      ),
                      AppQtyStepper(
                        value: _qty,
                        onChanged: (v) => setState(() => _qty = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'Add to Cart',
                    variant: AppButtonVariant.filled,
                    fullWidth: true,
                    icon: Icons.add_shopping_cart,
                    onPressed: () => Navigator.of(context).pop(_qty),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            AppButton(
              label: 'Back',
              variant: AppButtonVariant.plain,
              fullWidth: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photo(LumColors lum) {
    final product = widget.product;
    return ClayContainer(
        variant: ClayVariant.inset,
        color: lum.g100,
        borderRadius: AppRadius.md,
        isDark: lum.isDark,
        width: 88,
        height: 88,
        child: product.imageUrl == null
            ? Icon(kInvItemIcon, size: 32, color: lum.g500)
            : ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Image.network(
                  product.imageUrl!,
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Icon(kInvItemIcon, size: 32, color: lum.g500),
                ),
              ),
    );
  }
}
