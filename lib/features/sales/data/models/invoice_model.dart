import '../../domain/entities/invoice.dart';

class InvoiceModel {
  static Invoice fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      branchId: json['branch_id'] as String,
      invoiceNumber: json['invoice_number'] as String,
      customerId: json['customer_id'] as String?,
      cashierId: json['cashier_id'] as String,
      sessionId: json['session_id'] as String?,
      status: _parseStatus(json['status'] as String),
      saleType: _parseSaleType(json['sale_type'] as String),
      subtotal: double.tryParse(json['subtotal'].toString()) ?? 0,
      discountTotal: double.tryParse(json['discount_total'].toString()) ?? 0,
      taxTotal: double.tryParse(json['tax_total'].toString()) ?? 0,
      grandTotal: double.tryParse(json['grand_total'].toString()) ?? 0,
      paidAmount: double.tryParse(json['paid_amount'].toString()) ?? 0,
      balance: double.tryParse(json['balance'].toString()) ?? 0,
      changeAmount: double.tryParse(json['change_amount'].toString()) ?? 0,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static InvoiceStatus _parseStatus(String s) {
    return switch (s.toUpperCase()) {
      'DRAFT' => InvoiceStatus.draft,
      'CONFIRMED' => InvoiceStatus.confirmed,
      'PARTIALLY_PAID' => InvoiceStatus.partiallyPaid,
      'PAID' => InvoiceStatus.paid,
      'RETURNED' => InvoiceStatus.returned,
      'VOID' => InvoiceStatus.voided,
      _ => InvoiceStatus.draft,
    };
  }

  static SaleType _parseSaleType(String s) {
    return switch (s.toUpperCase()) {
      'CASH' => SaleType.cash,
      'CREDIT' => SaleType.credit,
      'MIXED' => SaleType.mixed,
      _ => SaleType.cash,
    };
  }
}
