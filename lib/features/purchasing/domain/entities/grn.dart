class Grn {
  final String id;
  final String tenantId;
  final String poId;
  final String grnNumber;
  final String? warehouseId;
  final String receivedBy;
  final DateTime receivedAt;
  final String? notes;

  const Grn({
    required this.id,
    required this.tenantId,
    required this.poId,
    required this.grnNumber,
    this.warehouseId,
    required this.receivedBy,
    required this.receivedAt,
    this.notes,
  });
}
