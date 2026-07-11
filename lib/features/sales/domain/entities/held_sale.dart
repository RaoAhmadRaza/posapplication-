class HeldSale {
  final String id;
  final String tenantId;
  final String branchId;
  final String? sessionId;
  final String? customerId;
  final String? customerName;
  final Map<String, dynamic> cartJson;
  final String label;
  final int itemCount;
  final DateTime createdAt;

  const HeldSale({
    required this.id,
    required this.tenantId,
    required this.branchId,
    this.sessionId,
    this.customerId,
    this.customerName,
    required this.cartJson,
    required this.label,
    required this.itemCount,
    required this.createdAt,
  });
}
