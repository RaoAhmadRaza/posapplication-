class StockTransferItem {
  final String id;
  final String transferId;
  final String productId;
  final String? variantId;
  final String? imeiId;
  final double qty;
  final double qtyReceived;
  final double costPrice;
  final String? notes;

  const StockTransferItem({
    required this.id,
    required this.transferId,
    required this.productId,
    this.variantId,
    this.imeiId,
    required this.qty,
    required this.qtyReceived,
    required this.costPrice,
    this.notes,
  });
}
