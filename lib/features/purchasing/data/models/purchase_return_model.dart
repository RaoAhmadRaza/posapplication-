import '../../domain/entities/purchase_return.dart';

class PurchaseReturnModel {
  static PurchaseReturn fromJson(Map<String, dynamic> json) {
    return PurchaseReturn(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      branchId: json['branch_id'] as String,
      supplierId: json['supplier_id'] as String,
      poId: json['po_id'] as String,
      grnId: json['grn_id'] as String?,
      invoiceId: json['invoice_id'] as String?,
      returnNumber: json['return_number'] as String,
      status: _parseStatus(json['status'] as String?),
      reason: json['reason'] as String?,
      returnDate: DateTime.parse(json['return_date'] as String),
      subtotal: double.tryParse(json['subtotal'].toString()) ?? 0,
      taxTotal: double.tryParse(json['tax_total'].toString()) ?? 0,
      totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static String statusToDb(PurchaseReturnStatus s) => switch (s) {
        PurchaseReturnStatus.draft => 'DRAFT',
        PurchaseReturnStatus.confirmed => 'CONFIRMED',
        PurchaseReturnStatus.cancelled => 'CANCELLED',
      };

  static PurchaseReturnStatus _parseStatus(String? s) {
    return switch ((s ?? 'CONFIRMED').toUpperCase()) {
      'DRAFT' => PurchaseReturnStatus.draft,
      'CONFIRMED' => PurchaseReturnStatus.confirmed,
      'CANCELLED' => PurchaseReturnStatus.cancelled,
      _ => PurchaseReturnStatus.confirmed,
    };
  }
}
