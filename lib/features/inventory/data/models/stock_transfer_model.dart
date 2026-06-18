import '../../domain/entities/stock_transfer.dart';
import '../../domain/entities/stock_transfer_status.dart';

class StockTransferModel {
  static StockTransfer fromJson(Map<String, dynamic> json) {
    return StockTransfer(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      transferNumber: json['transfer_number'] as String,
      fromBranchId: json['from_branch_id'] as String,
      toBranchId: json['to_branch_id'] as String,
      fromWarehouseId: json['from_warehouse_id'] as String?,
      toWarehouseId: json['to_warehouse_id'] as String?,
      status: StockTransferStatusX.fromDb(json['status'] as String),
      dispatchedAt: json['dispatched_at'] != null
          ? DateTime.tryParse(json['dispatched_at'] as String)
          : null,
      dispatchedBy: json['dispatched_by'] as String?,
      receivedAt: json['received_at'] != null
          ? DateTime.tryParse(json['received_at'] as String)
          : null,
      receivedBy: json['received_by'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
    );
  }

  static Map<String, dynamic> toJson(StockTransfer t) {
    return {
      'from_branch_id': t.fromBranchId,
      'to_branch_id': t.toBranchId,
      if (t.fromWarehouseId != null) 'from_warehouse_id': t.fromWarehouseId,
      if (t.toWarehouseId != null) 'to_warehouse_id': t.toWarehouseId,
      if (t.notes != null) 'notes': t.notes,
    };
  }
}
