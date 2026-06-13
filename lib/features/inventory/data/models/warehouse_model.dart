import '../../domain/entities/warehouse.dart';

class WarehouseModel {
  static Warehouse fromJson(Map<String, dynamic> json) {
    return Warehouse(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      branchId: json['branch_id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      address: json['address'] as String?,
      capacityNotes: json['capacity_notes'] as String?,
      isActive: json['is_active'] as bool,
      isDefault: json['is_default'] as bool,
    );
  }

  static Map<String, dynamic> toJson(Warehouse w) {
    return {
      'name': w.name,
      'code': w.code,
      'branch_id': w.branchId,
      if (w.address != null) 'address': w.address,
      if (w.capacityNotes != null) 'capacity_notes': w.capacityNotes,
      'is_active': w.isActive,
      'is_default': w.isDefault,
    };
  }
}
