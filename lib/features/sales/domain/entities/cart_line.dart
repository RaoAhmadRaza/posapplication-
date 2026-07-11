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

  double get discountAmount => (qty * unitPrice * discountPct / 100).roundToDouble();
  double get taxableAmount => (qty * unitPrice - discountAmount);
  double get taxAmount => (taxableAmount * taxPct / 100).roundToDouble();
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
