class SaleResult {
  final String invoiceId;
  final String invoiceNumber;
  final double grandTotal;
  final double paidAmount;
  final double balance;
  final double changeAmount;
  final String status;

  const SaleResult({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.grandTotal,
    required this.paidAmount,
    required this.balance,
    required this.changeAmount,
    required this.status,
  });
}
