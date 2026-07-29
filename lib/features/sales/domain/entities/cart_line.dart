class CartLine {
  final String id;
  final String productId;
  final String productName;
  final String? sku;
  final String? barcode;
  final double qty;
  final double unitPrice;
  final double discountPct;
  final double taxPct;
  final String? imeiId;

  const CartLine({
    required this.id,
    required this.productId,
    required this.productName,
    this.sku,
    this.barcode,
    required this.qty,
    required this.unitPrice,
    this.discountPct = 0,
    this.taxPct = 0,
    this.imeiId,
  });

  /// Mirrors create_sale's line math exactly — `round(x, 4)`, not to whole
  /// units. Rounding tax to the nearest unit here made the cart total land
  /// under the server's on any line whose tax fell below .5, and the sale was
  /// then refused as credit because the tender no longer covered it.
  static double _round4(double v) => (v * 10000).roundToDouble() / 10000;

  double get discountAmount => _round4(qty * unitPrice * discountPct / 100);
  double get taxableAmount => (qty * unitPrice - discountAmount);
  double get taxAmount => _round4(taxableAmount * taxPct / 100);
  double get lineTotal => taxableAmount + taxAmount;

  CartLine copyWith({double? qty, double? discountPct, double? taxPct}) {
    return CartLine(
      id: id,
      productId: productId,
      productName: productName,
      sku: sku,
      barcode: barcode,
      qty: qty ?? this.qty,
      unitPrice: unitPrice,
      discountPct: discountPct ?? this.discountPct,
      taxPct: taxPct ?? this.taxPct,
      imeiId: imeiId,
    );
  }
}
