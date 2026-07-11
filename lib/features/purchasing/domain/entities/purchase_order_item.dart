class PurchaseOrderItem {
  final String id;
  final String poId;
  final String productId;
  final String? variantId;
  final double qtyOrdered;
  final double qtyReceived;
  final double unitCost;
  final double unitCostBase;
  final double taxPct;
  final double discountPct;
  final double lineTotal;
  final double landedCostAllocated;

  const PurchaseOrderItem({
    required this.id,
    required this.poId,
    required this.productId,
    this.variantId,
    required this.qtyOrdered,
    required this.qtyReceived,
    required this.unitCost,
    required this.unitCostBase,
    required this.taxPct,
    required this.discountPct,
    required this.lineTotal,
    required this.landedCostAllocated,
  });

  double get qtyRemaining => qtyOrdered - qtyReceived;
}
