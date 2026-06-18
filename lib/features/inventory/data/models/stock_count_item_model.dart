import '../../domain/entities/stock_count_item.dart';

class StockCountItemModel {
  static StockCountItem fromJson(Map<String, dynamic> json) {
    return StockCountItem(
      id: json['id'] as String,
      stockCountId: json['stock_count_id'] as String,
      productId: json['product_id'] as String,
      variantId: json['variant_id'] as String?,
      systemQty: double.tryParse(json['system_qty'].toString()) ?? 0,
      countedQty: json['counted_qty'] != null
          ? double.tryParse(json['counted_qty'].toString())
          : null,
      variance: json['variance'] != null
          ? double.tryParse(json['variance'].toString())
          : null,
      varianceCost: json['variance_cost'] != null
          ? double.tryParse(json['variance_cost'].toString())
          : null,
      notes: json['notes'] as String?,
      countedAt: json['counted_at'] != null
          ? DateTime.tryParse(json['counted_at'] as String)
          : null,
      countedBy: json['counted_by'] as String?,
    );
  }

  static Map<String, dynamic> toJson(StockCountItem i) {
    return {
      'counted_qty': i.countedQty,
    };
  }
}
