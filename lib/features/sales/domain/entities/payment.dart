enum PaymentMethod { cash, bankTransfer, card, mobileWallet, cheque, loyaltyPoints, creditNote }

class Payment {
  final String id;
  final String tenantId;
  final String invoiceId;
  final PaymentMethod method;
  final double amount;
  final String? reference;
  final String? bankAccountId;
  final String? notes;
  final DateTime createdAt;

  const Payment({
    required this.id,
    required this.tenantId,
    required this.invoiceId,
    required this.method,
    required this.amount,
    this.reference,
    this.bankAccountId,
    this.notes,
    required this.createdAt,
  });
}
