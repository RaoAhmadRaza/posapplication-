class PurchaseReturnItem {
  final String id;
  final String returnId;
  final String poItemId;
  final String productId;
  final String? variantId;
  final double qtyReturned;
  final double unitCost;
  final double taxPct;
  final double lineTotal;
  final List<String>? imeiIds;

  const PurchaseReturnItem({
    required this.id,
    required this.returnId,
    required this.poItemId,
    required this.productId,
    this.variantId,
    required this.qtyReturned,
    required this.unitCost,
    required this.taxPct,
    required this.lineTotal,
    this.imeiIds,
  });
}
