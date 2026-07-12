/// Result of record_customer_payment: the settled invoice's new balance/status.
class CustomerPaymentResult {
  final String paymentId;
  final double balance;
  final String status;

  const CustomerPaymentResult({
    required this.paymentId,
    required this.balance,
    required this.status,
  });
}
