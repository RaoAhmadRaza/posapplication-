class GrnItem {
  final String id;
  final String grnId;
  final String poItemId;
  final String productId;
  final double qtyReceived;
  final double qtyRejected;
  final List<String>? imeiIds;
  final String? batchNumber;
  final DateTime? expiryDate;
  final String? notes;

  const GrnItem({
    required this.id,
    required this.grnId,
    required this.poItemId,
    required this.productId,
    required this.qtyReceived,
    required this.qtyRejected,
    this.imeiIds,
    this.batchNumber,
    this.expiryDate,
    this.notes,
  });
}
