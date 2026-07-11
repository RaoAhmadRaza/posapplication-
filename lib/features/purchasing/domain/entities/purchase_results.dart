// Typed results from the mutating RPCs (each returns a single jsonb Map).

class PoCreateResult {
  final String poId;
  final String poNumber;
  final double grandTotal;
  const PoCreateResult(
      {required this.poId, required this.poNumber, required this.grandTotal});
}

class PoStatusResult {
  final String poId;
  final String status;
  const PoStatusResult({required this.poId, required this.status});
}

class ReceiveResult {
  final String grnId;
  final String grnNumber;
  final String poStatus;
  const ReceiveResult(
      {required this.grnId, required this.grnNumber, required this.poStatus});
}

class InvoiceCreateResult {
  final String invoiceId;
  final double totalAmount;
  final double matchVariance;
  const InvoiceCreateResult({
    required this.invoiceId,
    required this.totalAmount,
    required this.matchVariance,
  });
}

class PaymentResult {
  final String paymentId;
  final String voucherNumber;
  const PaymentResult(
      {required this.paymentId, required this.voucherNumber});
}

class ReturnCreateResult {
  final String returnId;
  final String returnNumber;
  final double totalAmount;
  const ReturnCreateResult({
    required this.returnId,
    required this.returnNumber,
    required this.totalAmount,
  });
}
