class StockBalance {
  final String id;
  final String branchId;
  final String? warehouseId;
  final String productId;
  final String? variantId;
  final double qtyOnHand;
  final double qtyReserved;
  final double qtyInTransit;
  final double avgCost;
  final int? reorderPoint;
  final DateTime? lastStockTake;
  final DateTime lastUpdated;

  const StockBalance({
    required this.id,
    required this.branchId,
    this.warehouseId,
    required this.productId,
    this.variantId,
    required this.qtyOnHand,
    required this.qtyReserved,
    required this.qtyInTransit,
    required this.avgCost,
    this.reorderPoint,
    this.lastStockTake,
    required this.lastUpdated,
  });
}
