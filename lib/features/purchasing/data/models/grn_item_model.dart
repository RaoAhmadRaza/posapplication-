import '../../domain/entities/grn_item.dart';

class GrnItemModel {
  static GrnItem fromJson(Map<String, dynamic> json) {
    return GrnItem(
      id: json['id'] as String,
      grnId: json['grn_id'] as String,
      poItemId: json['po_item_id'] as String,
      productId: json['product_id'] as String,
      qtyReceived: double.tryParse(json['qty_received'].toString()) ?? 0,
      qtyRejected: double.tryParse(json['qty_rejected'].toString()) ?? 0,
      imeiIds: (json['imei_ids_json'] as List?)?.cast<String>(),
      batchNumber: json['batch_number'] as String?,
      expiryDate: json['expiry_date'] == null
          ? null
          : DateTime.tryParse(json['expiry_date'].toString()),
      notes: json['notes'] as String?,
    );
  }
}
