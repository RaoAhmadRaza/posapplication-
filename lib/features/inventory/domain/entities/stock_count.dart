import 'stock_count_status.dart';

class StockCount {
  final String id;
  final String tenantId;
  final String branchId;
  final String? warehouseId;
  final String countNumber;
  final StockCountStatus status;
  final String? categoryId;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int totalItems;
  final int itemsCounted;
  final int varianceCount;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const StockCount({
    required this.id,
    required this.tenantId,
    required this.branchId,
    this.warehouseId,
    required this.countNumber,
    required this.status,
    this.categoryId,
    this.startedAt,
    this.completedAt,
    required this.totalItems,
    required this.itemsCounted,
    required this.varianceCount,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });
}
