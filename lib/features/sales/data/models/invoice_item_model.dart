import '../../domain/entities/invoice_item.dart';

class InvoiceItemModel {
  static InvoiceItem fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      id: json['id'] as String,
      invoiceId: json['invoice_id'] as String,
      productId: json['product_id'] as String,
      variantId: json['variant_id'] as String?,
      imeiId: json['imei_id'] as String?,
      description: json['description'] as String?,
      qty: double.tryParse(json['qty'].toString()) ?? 0,
      unitPrice: double.tryParse(json['unit_price'].toString()) ?? 0,
      costPrice: double.tryParse(json['cost_price'].toString()) ?? 0,
      discountPct: double.tryParse(json['discount_pct'].toString()) ?? 0,
      discountAmount: double.tryParse(json['discount_amount'].toString()) ?? 0,
      taxPct: double.tryParse(json['tax_pct'].toString()) ?? 0,
      taxAmount: double.tryParse(json['tax_amount'].toString()) ?? 0,
      lineTotal: double.tryParse(json['line_total'].toString()) ?? 0,
      profit: double.tryParse(json['profit'].toString()) ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
