class StockCountItem {
  final String id;
  final String stockCountId;
  final String productId;
  final String? variantId;
  final double systemQty;
  final double? countedQty;
  final double? variance;
  final double? varianceCost;
  final String? notes;
  final DateTime? countedAt;
  final String? countedBy;

  const StockCountItem({
    required this.id,
    required this.stockCountId,
    required this.productId,
    this.variantId,
    required this.systemQty,
    this.countedQty,
    this.variance,
    this.varianceCost,
    this.notes,
    this.countedAt,
    this.countedBy,
  });
}
