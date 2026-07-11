class SupplierPayment {
  final String id;
  final String tenantId;
  final String supplierId;
  final String? invoiceId;
  final String method;
  final double amount;
  final String? reference;
  final String? voucherNumber;
  final String? notes;
  final DateTime paidAt;

  const SupplierPayment({
    required this.id,
    required this.tenantId,
    required this.supplierId,
    this.invoiceId,
    required this.method,
    required this.amount,
    this.reference,
    this.voucherNumber,
    this.notes,
    required this.paidAt,
  });
}
