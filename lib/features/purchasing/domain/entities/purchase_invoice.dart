enum PurchaseInvoiceStatus { draft, pending, approved, paid, void_ }

class PurchaseInvoice {
  final String id;
  final String tenantId;
  final String poId;
  final String? grnId;
  final String supplierId;
  final String? supplierInvoiceNumber;
  final double amount;
  final double taxAmount;
  final double totalAmount;
  final double paidAmount;
  final double balance;
  final PurchaseInvoiceStatus status;
  final DateTime? dueDate;
  final String? notes;
  final DateTime createdAt;

  const PurchaseInvoice({
    required this.id,
    required this.tenantId,
    required this.poId,
    this.grnId,
    required this.supplierId,
    this.supplierInvoiceNumber,
    required this.amount,
    required this.taxAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.balance,
    required this.status,
    this.dueDate,
    this.notes,
    required this.createdAt,
  });
}
