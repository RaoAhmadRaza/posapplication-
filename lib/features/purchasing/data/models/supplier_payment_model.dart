import '../../domain/entities/supplier_payment.dart';

class SupplierPaymentModel {
  static SupplierPayment fromJson(Map<String, dynamic> json) {
    return SupplierPayment(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      supplierId: json['supplier_id'] as String,
      invoiceId: json['invoice_id'] as String?,
      method: json['method'] as String,
      amount: double.tryParse(json['amount'].toString()) ?? 0,
      reference: json['reference'] as String?,
      voucherNumber: json['voucher_number'] as String?,
      notes: json['notes'] as String?,
      paidAt: DateTime.parse(json['paid_at'] as String),
    );
  }
}
