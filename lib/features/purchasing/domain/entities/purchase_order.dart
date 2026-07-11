enum PurchaseOrderStatus {
  draft,
  submitted,
  approved,
  partiallyReceived,
  received,
  invoiced,
  closed,
  cancelled,
}

class PurchaseOrder {
  final String id;
  final String tenantId;
  final String branchId;
  final String supplierId;
  final String poNumber;
  final PurchaseOrderStatus status;
  final DateTime orderDate;
  final DateTime? expectedDate;
  final String currency;
  final double exchangeRate;
  final double subtotal;
  final double taxTotal;
  final double discountTotal;
  final double freightCharges;
  final double insuranceCharges;
  final double customDuty;
  final double landedCost;
  final double grandTotal;
  final String? notes;
  final DateTime? approvedAt;
  final DateTime createdAt;

  const PurchaseOrder({
    required this.id,
    required this.tenantId,
    required this.branchId,
    required this.supplierId,
    required this.poNumber,
    required this.status,
    required this.orderDate,
    this.expectedDate,
    required this.currency,
    required this.exchangeRate,
    required this.subtotal,
    required this.taxTotal,
    required this.discountTotal,
    required this.freightCharges,
    required this.insuranceCharges,
    required this.customDuty,
    required this.landedCost,
    required this.grandTotal,
    this.notes,
    this.approvedAt,
    required this.createdAt,
  });
}
