import 'stock_movement_type.dart';

class StockLedgerEntry {
  final String id;
  final String productId;
  final String? variantId;
  final String branchId;
  final String? warehouseId;
  final StockMovementType operationType;
  final double qtyChange;
  final double costPerUnit;
  final double totalCost;
  final double balanceAfter;
  final double avgCostAfter;
  final String referenceType;
  final String referenceId;
  final String? notes;
  final DateTime createdAt;

  const StockLedgerEntry({
    required this.id,
    required this.productId,
    this.variantId,
    required this.branchId,
    this.warehouseId,
    required this.operationType,
    required this.qtyChange,
    required this.costPerUnit,
    required this.totalCost,
    required this.balanceAfter,
    required this.avgCostAfter,
    required this.referenceType,
    required this.referenceId,
    this.notes,
    required this.createdAt,
  });
}
