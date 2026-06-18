import 'imei_status.dart';

class ImeiRecord {
  final String id;
  final String tenantId;
  final String imei;
  final String productId;
  final String? variantId;
  final ImeiStatus status;
  final String branchId;
  final String? warehouseId;
  final String sourceType;
  final String? sourceId;
  final double costPrice;
  final double? sellingPrice;
  final DateTime? warrantyExpiresAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const ImeiRecord({
    required this.id,
    required this.tenantId,
    required this.imei,
    required this.productId,
    this.variantId,
    required this.status,
    required this.branchId,
    this.warehouseId,
    required this.sourceType,
    this.sourceId,
    required this.costPrice,
    this.sellingPrice,
    this.warrantyExpiresAt,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });
}
