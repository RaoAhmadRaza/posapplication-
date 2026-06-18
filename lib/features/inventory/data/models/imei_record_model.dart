import '../../domain/entities/imei_record.dart';
import '../../domain/entities/imei_status.dart';

class ImeiRecordModel {
  static ImeiRecord fromJson(Map<String, dynamic> json) {
    return ImeiRecord(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      imei: json['imei'] as String,
      productId: json['product_id'] as String,
      variantId: json['variant_id'] as String?,
      status: ImeiStatusX.fromDb(json['status'] as String),
      branchId: json['branch_id'] as String,
      warehouseId: json['warehouse_id'] as String?,
      sourceType: json['source_type'] as String,
      sourceId: json['source_id'] as String?,
      costPrice: double.tryParse(json['cost_price'].toString()) ?? 0,
      sellingPrice: json['selling_price'] != null
          ? double.tryParse(json['selling_price'].toString())
          : null,
      warrantyExpiresAt: json['warranty_expires_at'] != null
          ? DateTime.tryParse(json['warranty_expires_at'] as String)
          : null,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
    );
  }

  static Map<String, dynamic> toJson(ImeiRecord r) {
    return {
      'imei': r.imei,
      'product_id': r.productId,
      if (r.variantId != null) 'variant_id': r.variantId,
      'branch_id': r.branchId,
      if (r.warehouseId != null) 'warehouse_id': r.warehouseId,
      'source_type': r.sourceType,
      'cost_price': r.costPrice,
      if (r.notes != null) 'notes': r.notes,
    };
  }
}
