enum InvoiceStatus { draft, confirmed, partiallyPaid, paid, returned, voided }

enum SaleType { cash, credit, mixed }

class Invoice {
  final String id;
  final String tenantId;
  final String branchId;
  final String invoiceNumber;
  final String? customerId;
  final String cashierId;
  final String? sessionId;
  final InvoiceStatus status;
  final SaleType saleType;
  final double subtotal;
  final double discountTotal;
  final double taxTotal;
  final double grandTotal;
  final double paidAmount;
  final double balance;
  final double changeAmount;
  final String? notes;
  final DateTime createdAt;

  const Invoice({
    required this.id,
    required this.tenantId,
    required this.branchId,
    required this.invoiceNumber,
    this.customerId,
    required this.cashierId,
    this.sessionId,
    required this.status,
    required this.saleType,
    required this.subtotal,
    required this.discountTotal,
    required this.taxTotal,
    required this.grandTotal,
    required this.paidAmount,
    required this.balance,
    required this.changeAmount,
    this.notes,
    required this.createdAt,
  });
}
