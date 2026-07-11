import '../../domain/entities/payment.dart';

class PaymentModel {
  static Payment fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      invoiceId: json['invoice_id'] as String,
      method: _parseMethod(json['method'] as String),
      amount: double.tryParse(json['amount'].toString()) ?? 0,
      reference: json['reference'] as String?,
      bankAccountId: json['bank_account_id'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static PaymentMethod _parseMethod(String s) {
    return switch (s.toUpperCase()) {
      'CASH' => PaymentMethod.cash,
      'BANK_TRANSFER' => PaymentMethod.bankTransfer,
      'CARD' => PaymentMethod.card,
      'MOBILE_WALLET' => PaymentMethod.mobileWallet,
      'CHEQUE' => PaymentMethod.cheque,
      'LOYALTY_POINTS' => PaymentMethod.loyaltyPoints,
      'CREDIT_NOTE' => PaymentMethod.creditNote,
      _ => PaymentMethod.cash,
    };
  }
}
