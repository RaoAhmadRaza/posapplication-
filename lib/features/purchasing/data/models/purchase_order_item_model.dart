import '../../domain/entities/purchase_order_item.dart';

class PurchaseOrderItemModel {
  static PurchaseOrderItem fromJson(Map<String, dynamic> json) {
    return PurchaseOrderItem(
      id: json['id'] as String,
      poId: json['po_id'] as String,
      productId: json['product_id'] as String,
      variantId: json['variant_id'] as String?,
      qtyOrdered: double.tryParse(json['qty_ordered'].toString()) ?? 0,
      qtyReceived: double.tryParse(json['qty_received'].toString()) ?? 0,
      unitCost: double.tryParse(json['unit_cost'].toString()) ?? 0,
      unitCostBase: double.tryParse(json['unit_cost_base'].toString()) ?? 0,
      taxPct: double.tryParse(json['tax_pct'].toString()) ?? 0,
      discountPct: double.tryParse(json['discount_pct'].toString()) ?? 0,
      lineTotal: double.tryParse(json['line_total'].toString()) ?? 0,
      landedCostAllocated:
          double.tryParse(json['landed_cost_allocated'].toString()) ?? 0,
    );
  }
}
