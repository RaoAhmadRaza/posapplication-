import '../../domain/entities/stock_balance.dart';

class StockBalanceModel {
  static StockBalance fromJson(Map<String, dynamic> json) {
    return StockBalance(
      id: json['id'] as String,
      branchId: json['branch_id'] as String,
      warehouseId: json['warehouse_id'] as String?,
      productId: json['product_id'] as String,
      variantId: json['variant_id'] as String?,
      qtyOnHand: double.tryParse(json['qty_on_hand'].toString()) ?? 0,
      qtyReserved: double.tryParse(json['qty_reserved'].toString()) ?? 0,
      qtyInTransit: double.tryParse(json['qty_in_transit'].toString()) ?? 0,
      avgCost: double.tryParse(json['avg_cost'].toString()) ?? 0,
      reorderPoint: json['reorder_point'] as int?,
      lastStockTake: json['last_stock_take'] != null
          ? DateTime.tryParse(json['last_stock_take'] as String)
          : null,
      lastUpdated: DateTime.parse(json['last_updated'] as String),
    );
  }

  static Map<String, dynamic> toJson(StockBalance b) {
    return {
      'product_id': b.productId,
      'branch_id': b.branchId,
      if (b.warehouseId != null) 'warehouse_id': b.warehouseId,
      if (b.variantId != null) 'variant_id': b.variantId,
    };
  }
}
