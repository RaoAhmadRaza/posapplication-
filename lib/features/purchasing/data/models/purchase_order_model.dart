import '../../domain/entities/purchase_order.dart';

class PurchaseOrderModel {
  static PurchaseOrder fromJson(Map<String, dynamic> json) {
    return PurchaseOrder(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      branchId: json['branch_id'] as String,
      supplierId: json['supplier_id'] as String,
      poNumber: json['po_number'] as String,
      status: _parseStatus(json['status'] as String?),
      orderDate: DateTime.parse(json['order_date'] as String),
      expectedDate: json['expected_date'] == null
          ? null
          : DateTime.tryParse(json['expected_date'].toString()),
      currency: json['currency'] as String? ?? 'PKR',
      exchangeRate: double.tryParse(json['exchange_rate'].toString()) ?? 1,
      subtotal: double.tryParse(json['subtotal'].toString()) ?? 0,
      taxTotal: double.tryParse(json['tax_total'].toString()) ?? 0,
      discountTotal: double.tryParse(json['discount_total'].toString()) ?? 0,
      freightCharges: double.tryParse(json['freight_charges'].toString()) ?? 0,
      insuranceCharges:
          double.tryParse(json['insurance_charges'].toString()) ?? 0,
      customDuty: double.tryParse(json['custom_duty'].toString()) ?? 0,
      landedCost: double.tryParse(json['landed_cost'].toString()) ?? 0,
      grandTotal: double.tryParse(json['grand_total'].toString()) ?? 0,
      notes: json['notes'] as String?,
      approvedAt: json['approved_at'] == null
          ? null
          : DateTime.tryParse(json['approved_at'].toString()),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static String statusToDb(PurchaseOrderStatus s) => switch (s) {
        PurchaseOrderStatus.draft => 'DRAFT',
        PurchaseOrderStatus.submitted => 'SUBMITTED',
        PurchaseOrderStatus.approved => 'APPROVED',
        PurchaseOrderStatus.partiallyReceived => 'PARTIALLY_RECEIVED',
        PurchaseOrderStatus.received => 'RECEIVED',
        PurchaseOrderStatus.invoiced => 'INVOICED',
        PurchaseOrderStatus.closed => 'CLOSED',
        PurchaseOrderStatus.cancelled => 'CANCELLED',
      };

  static PurchaseOrderStatus _parseStatus(String? s) {
    return switch ((s ?? 'DRAFT').toUpperCase()) {
      'DRAFT' => PurchaseOrderStatus.draft,
      'SUBMITTED' => PurchaseOrderStatus.submitted,
      'APPROVED' => PurchaseOrderStatus.approved,
      'PARTIALLY_RECEIVED' => PurchaseOrderStatus.partiallyReceived,
      'RECEIVED' => PurchaseOrderStatus.received,
      'INVOICED' => PurchaseOrderStatus.invoiced,
      'CLOSED' => PurchaseOrderStatus.closed,
      'CANCELLED' => PurchaseOrderStatus.cancelled,
      _ => PurchaseOrderStatus.draft,
    };
  }
}
