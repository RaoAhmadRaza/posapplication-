import '../../domain/entities/purchase_return_item.dart';

class PurchaseReturnItemModel {
  static PurchaseReturnItem fromJson(Map<String, dynamic> json) {
    return PurchaseReturnItem(
      id: json['id'] as String,
      returnId: json['return_id'] as String,
      poItemId: json['po_item_id'] as String,
      productId: json['product_id'] as String,
      variantId: json['variant_id'] as String?,
      qtyReturned: double.tryParse(json['qty_returned'].toString()) ?? 0,
      unitCost: double.tryParse(json['unit_cost'].toString()) ?? 0,
      taxPct: double.tryParse(json['tax_pct'].toString()) ?? 0,
      lineTotal: double.tryParse(json['line_total'].toString()) ?? 0,
      imeiIds: (json['imei_ids_json'] as List?)?.cast<String>(),
    );
  }
}
