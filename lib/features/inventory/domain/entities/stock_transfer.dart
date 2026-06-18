import 'stock_transfer_status.dart';

class StockTransfer {
  final String id;
  final String tenantId;
  final String transferNumber;
  final String fromBranchId;
  final String toBranchId;
  final String? fromWarehouseId;
  final String? toWarehouseId;
  final StockTransferStatus status;
  final DateTime? dispatchedAt;
  final String? dispatchedBy;
  final DateTime? receivedAt;
  final String? receivedBy;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const StockTransfer({
    required this.id,
    required this.tenantId,
    required this.transferNumber,
    required this.fromBranchId,
    required this.toBranchId,
    this.fromWarehouseId,
    this.toWarehouseId,
    required this.status,
    this.dispatchedAt,
    this.dispatchedBy,
    this.receivedAt,
    this.receivedBy,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });
}
