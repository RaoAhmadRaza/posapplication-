import '../../domain/entities/grn.dart';

class GrnModel {
  static Grn fromJson(Map<String, dynamic> json) {
    return Grn(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      poId: json['po_id'] as String,
      grnNumber: json['grn_number'] as String,
      warehouseId: json['warehouse_id'] as String?,
      receivedBy: json['received_by'] as String,
      receivedAt: DateTime.parse(json['received_at'] as String),
      notes: json['notes'] as String?,
    );
  }
}
