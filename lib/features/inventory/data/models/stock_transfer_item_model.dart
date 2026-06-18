import '../../domain/entities/stock_transfer_item.dart';

class StockTransferItemModel {
  static StockTransferItem fromJson(Map<String, dynamic> json) {
    return StockTransferItem(
      id: json['id'] as String,
      transferId: json['transfer_id'] as String,
      productId: json['product_id'] as String,
      variantId: json['variant_id'] as String?,
      imeiId: json['imei_id'] as String?,
      qty: double.tryParse(json['qty'].toString()) ?? 0,
      qtyReceived: double.tryParse(json['qty_received'].toString()) ?? 0,
      costPrice: double.tryParse(json['cost_price'].toString()) ?? 0,
      notes: json['notes'] as String?,
    );
  }

  static Map<String, dynamic> toJson(StockTransferItem i) {
    return {
      'product_id': i.productId,
      if (i.variantId != null) 'variant_id': i.variantId,
      'qty': i.qty,
      'cost_price': i.costPrice,
    };
  }
}
