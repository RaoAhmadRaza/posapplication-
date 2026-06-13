class StockLevel {
  final String productId;
  final String productName;
  final String productSku;
  final int reorderPoint;
  final String? warehouseId;
  final String? variantId;
  final double qtyOnHand;
  final double qtyReserved;
  final double qtyInTransit;
  final double avgCost;

  const StockLevel({
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.reorderPoint,
    this.warehouseId,
    this.variantId,
    required this.qtyOnHand,
    required this.qtyReserved,
    required this.qtyInTransit,
    required this.avgCost,
  });

  double get available => qtyOnHand - qtyReserved;

  bool get isLowStock => qtyOnHand > 0 && qtyOnHand <= reorderPoint;
}
