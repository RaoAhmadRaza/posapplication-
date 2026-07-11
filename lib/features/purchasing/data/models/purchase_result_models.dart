import '../../domain/entities/purchase_results.dart';

class PoCreateResultModel {
  static PoCreateResult fromJson(Map<String, dynamic> json) {
    return PoCreateResult(
      poId: json['po_id'] as String,
      poNumber: json['po_number'] as String,
      grandTotal: double.tryParse(json['grand_total'].toString()) ?? 0,
    );
  }
}

class PoStatusResultModel {
  static PoStatusResult fromJson(Map<String, dynamic> json) {
    return PoStatusResult(
      poId: json['po_id'] as String,
      status: json['status'] as String,
    );
  }
}

class ReceiveResultModel {
  static ReceiveResult fromJson(Map<String, dynamic> json) {
    return ReceiveResult(
      grnId: json['grn_id'] as String,
      grnNumber: json['grn_number'] as String,
      poStatus: json['po_status'] as String,
    );
  }
}

class InvoiceCreateResultModel {
  static InvoiceCreateResult fromJson(Map<String, dynamic> json) {
    return InvoiceCreateResult(
      invoiceId: json['invoice_id'] as String,
      totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0,
      matchVariance: double.tryParse(json['match_variance'].toString()) ?? 0,
    );
  }
}

class PaymentResultModel {
  static PaymentResult fromJson(Map<String, dynamic> json) {
    return PaymentResult(
      paymentId: json['payment_id'] as String,
      voucherNumber: json['voucher_number'] as String,
    );
  }
}
