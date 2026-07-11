import '../../domain/entities/sale_result.dart';

class SaleResultModel {
  static SaleResult fromJson(Map<String, dynamic> json) {
    return SaleResult(
      invoiceId: json['invoice_id'] as String,
      invoiceNumber: json['invoice_number'] as String,
      grandTotal: double.tryParse(json['grand_total'].toString()) ?? 0,
      paidAmount: double.tryParse(json['paid_amount'].toString()) ?? 0,
      balance: double.tryParse(json['balance'].toString()) ?? 0,
      changeAmount: double.tryParse(json['change_amount'].toString()) ?? 0,
      status: json['status'] as String,
    );
  }
}
