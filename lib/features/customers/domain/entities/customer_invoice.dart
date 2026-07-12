/// An unpaid (or partially paid) sale invoice for a customer — the pick list
/// for collecting a credit payment.
class CustomerInvoice {
  final String id;
  final String invoiceNumber;
  final double grandTotal;
  final double balance;
  final String status;
  final DateTime createdAt;

  const CustomerInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.grandTotal,
    required this.balance,
    required this.status,
    required this.createdAt,
  });
}
