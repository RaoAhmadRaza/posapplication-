import '../../domain/entities/stock_ledger_entry.dart';
import '../../domain/entities/stock_movement_type.dart';

class StockLedgerEntryModel {
  static StockLedgerEntry fromJson(Map<String, dynamic> json) {
    return StockLedgerEntry(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      variantId: json['variant_id'] as String?,
      branchId: json['branch_id'] as String,
      warehouseId: json['warehouse_id'] as String?,
      operationType: StockMovementTypeX.fromDb(json['operation_type'] as String),
      qtyChange: double.tryParse(json['qty_change'].toString()) ?? 0,
      costPerUnit: double.tryParse(json['cost_per_unit'].toString()) ?? 0,
      totalCost: double.tryParse(json['total_cost'].toString()) ?? 0,
      balanceAfter: double.tryParse(json['balance_after'].toString()) ?? 0,
      avgCostAfter: double.tryParse(json['avg_cost_after'].toString()) ?? 0,
      referenceType: json['reference_type'] as String,
      referenceId: json['reference_id'] as String,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static Map<String, dynamic> toJson(StockLedgerEntry e) {
    return {
      'product_id': e.productId,
      if (e.variantId != null) 'variant_id': e.variantId,
      'branch_id': e.branchId,
      if (e.warehouseId != null) 'warehouse_id': e.warehouseId,
      'operation_type': e.operationType.dbValue,
      'qty_change': e.qtyChange,
      'cost_per_unit': e.costPerUnit,
      'reference_type': e.referenceType,
      'reference_id': e.referenceId,
      if (e.notes != null) 'notes': e.notes,
    };
  }
}
