class InvoiceItem {
  final String id;
  final String invoiceId;
  final String productId;
  final String? variantId;
  final String? imeiId;
  final String? description;
  final double qty;
  final double unitPrice;
  final double costPrice;
  final double discountPct;
  final double discountAmount;
  final double taxPct;
  final double taxAmount;
  final double lineTotal;
  final double profit;
  final DateTime createdAt;

  const InvoiceItem({
    required this.id,
    required this.invoiceId,
    required this.productId,
    this.variantId,
    this.imeiId,
    this.description,
    required this.qty,
    required this.unitPrice,
    required this.costPrice,
    required this.discountPct,
    required this.discountAmount,
    required this.taxPct,
    required this.taxAmount,
    required this.lineTotal,
    required this.profit,
    required this.createdAt,
  });
}
