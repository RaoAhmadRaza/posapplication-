import 'adjustment_reason.dart';

class StockAdjustment {
  final String id;
  final String tenantId;
  final String branchId;
  final String? warehouseId;
  final String productId;
  final String? variantId;
  final double adjQty;
  final double costPerUnit;
  final AdjustmentReason reasonCode;
  final String? reasonNotes;
  final String? referenceNumber;
  final bool requiresApproval;
  final String? approvedBy;
  final DateTime? approvedAt;
  final bool posted;
  final DateTime createdAt;
  final String? createdBy;

  const StockAdjustment({
    required this.id,
    required this.tenantId,
    required this.branchId,
    this.warehouseId,
    required this.productId,
    this.variantId,
    required this.adjQty,
    required this.costPerUnit,
    required this.reasonCode,
    this.reasonNotes,
    this.referenceNumber,
    required this.requiresApproval,
    this.approvedBy,
    this.approvedAt,
    required this.posted,
    required this.createdAt,
    this.createdBy,
  });
}
