enum PurchaseReturnStatus { draft, confirmed, cancelled }

class PurchaseReturn {
  final String id;
  final String tenantId;
  final String branchId;
  final String supplierId;
  final String poId;
  final String? grnId;
  final String? invoiceId;
  final String returnNumber;
  final PurchaseReturnStatus status;
  final String? reason;
  final DateTime returnDate;
  final double subtotal;
  final double taxTotal;
  final double totalAmount;
  final String? notes;
  final DateTime createdAt;

  const PurchaseReturn({
    required this.id,
    required this.tenantId,
    required this.branchId,
    required this.supplierId,
    required this.poId,
    this.grnId,
    this.invoiceId,
    required this.returnNumber,
    required this.status,
    this.reason,
    required this.returnDate,
    required this.subtotal,
    required this.taxTotal,
    required this.totalAmount,
    this.notes,
    required this.createdAt,
  });
}
