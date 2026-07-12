import '../../domain/entities/customer_invoice.dart';

class CustomerInvoiceModel {
  static CustomerInvoice fromJson(Map<String, dynamic> j) {
    return CustomerInvoice(
      id: j['id'] as String,
      invoiceNumber: j['invoice_number'] as String? ?? '',
      grandTotal: double.tryParse(j['grand_total'].toString()) ?? 0,
      balance: double.tryParse(j['balance'].toString()) ?? 0,
      status: j['status'] as String? ?? '',
      createdAt:
          DateTime.tryParse(j['created_at'].toString())?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
