import '../../domain/entities/stock_adjustment.dart';
import '../../domain/entities/adjustment_reason.dart';

class StockAdjustmentModel {
  static StockAdjustment fromJson(Map<String, dynamic> json) {
    return StockAdjustment(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      branchId: json['branch_id'] as String,
      warehouseId: json['warehouse_id'] as String?,
      productId: json['product_id'] as String,
      variantId: json['variant_id'] as String?,
      adjQty: double.tryParse(json['adj_qty'].toString()) ?? 0,
      costPerUnit: double.tryParse(json['cost_per_unit'].toString()) ?? 0,
      reasonCode: AdjustmentReasonX.fromDb(json['reason_code'] as String),
      reasonNotes: json['reason_notes'] as String?,
      referenceNumber: json['reference_number'] as String?,
      requiresApproval: json['requires_approval'] as bool,
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'] as String)
          : null,
      posted: json['posted'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
    );
  }

  static Map<String, dynamic> toJson(StockAdjustment a) {
    return {
      'branch_id': a.branchId,
      if (a.warehouseId != null) 'warehouse_id': a.warehouseId,
      'product_id': a.productId,
      if (a.variantId != null) 'variant_id': a.variantId,
      'adj_qty': a.adjQty,
      'cost_per_unit': a.costPerUnit,
      'reason_code': a.reasonCode.dbValue,
      if (a.reasonNotes != null) 'reason_notes': a.reasonNotes,
    };
  }
}
