class RepairPart {
  final String id;
  final String repairId;
  final String productId;
  final double qty;
  final double unitCost;
  final double totalCost;
  final String? notes;
  final DateTime createdAt;

  /// Display-only, from the embedded `products(name)` join on load.
  final String? productName;

  const RepairPart({
    required this.id,
    required this.repairId,
    required this.productId,
    required this.qty,
    required this.unitCost,
    required this.totalCost,
    this.notes,
    required this.createdAt,
    this.productName,
  });
}
