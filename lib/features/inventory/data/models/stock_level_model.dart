import '../../domain/entities/stock_level.dart';

class StockLevelModel {
  static StockLevel fromJson(Map<String, dynamic> json) {
    final product = json['products'] as Map<String, dynamic>? ?? {};
    return StockLevel(
      productId: json['product_id'] as String,
      productName: product['name'] as String? ?? '',
      productSku: product['sku'] as String? ?? '',
      reorderPoint: product['reorder_point'] as int? ?? 0,
      warehouseId: json['warehouse_id'] as String?,
      variantId: json['variant_id'] as String?,
      qtyOnHand: double.tryParse(json['qty_on_hand'].toString()) ?? 0,
      qtyReserved: double.tryParse(json['qty_reserved'].toString()) ?? 0,
      qtyInTransit: double.tryParse(json['qty_in_transit'].toString()) ?? 0,
      avgCost: double.tryParse(json['avg_cost'].toString()) ?? 0,
    );
  }
}
