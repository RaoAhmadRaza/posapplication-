import '../../domain/entities/stock_count.dart';
import '../../domain/entities/stock_count_status.dart';

class StockCountModel {
  static StockCount fromJson(Map<String, dynamic> json) {
    return StockCount(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      branchId: json['branch_id'] as String,
      warehouseId: json['warehouse_id'] as String?,
      countNumber: json['count_number'] as String,
      status: StockCountStatusX.fromDb(json['status'] as String),
      categoryId: json['category_id'] as String?,
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
      totalItems: json['total_items'] as int,
      itemsCounted: json['items_counted'] as int,
      varianceCount: json['variance_count'] as int,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
    );
  }

  static Map<String, dynamic> toJson(StockCount c) {
    return {
      'branch_id': c.branchId,
      if (c.warehouseId != null) 'warehouse_id': c.warehouseId,
      if (c.categoryId != null) 'category_id': c.categoryId,
    };
  }
}
