import '../../domain/entities/purchase_invoice.dart';

class PurchaseInvoiceModel {
  static PurchaseInvoice fromJson(Map<String, dynamic> json) {
    return PurchaseInvoice(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      poId: json['po_id'] as String,
      grnId: json['grn_id'] as String?,
      supplierId: json['supplier_id'] as String,
      supplierInvoiceNumber: json['supplier_invoice_number'] as String?,
      amount: double.tryParse(json['amount'].toString()) ?? 0,
      taxAmount: double.tryParse(json['tax_amount'].toString()) ?? 0,
      totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0,
      paidAmount: double.tryParse(json['paid_amount'].toString()) ?? 0,
      balance: double.tryParse(json['balance'].toString()) ?? 0,
      status: _parseStatus(json['status'] as String?),
      dueDate: json['due_date'] == null
          ? null
          : DateTime.tryParse(json['due_date'].toString()),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static String statusToDb(PurchaseInvoiceStatus s) => switch (s) {
        PurchaseInvoiceStatus.draft => 'DRAFT',
        PurchaseInvoiceStatus.pending => 'PENDING',
        PurchaseInvoiceStatus.approved => 'APPROVED',
        PurchaseInvoiceStatus.paid => 'PAID',
        PurchaseInvoiceStatus.void_ => 'VOID',
      };

  static PurchaseInvoiceStatus _parseStatus(String? s) {
    return switch ((s ?? 'DRAFT').toUpperCase()) {
      'DRAFT' => PurchaseInvoiceStatus.draft,
      'PENDING' => PurchaseInvoiceStatus.pending,
      'APPROVED' => PurchaseInvoiceStatus.approved,
      'PAID' => PurchaseInvoiceStatus.paid,
      'VOID' => PurchaseInvoiceStatus.void_,
      _ => PurchaseInvoiceStatus.draft,
    };
  }
}
