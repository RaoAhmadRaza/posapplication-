import '../../domain/entities/repair_part.dart';

class RepairPartModel {
  static RepairPart fromJson(Map<String, dynamic> json) {
    return RepairPart(
      id: json['id'] as String,
      repairId: json['repair_id'] as String,
      productId: json['product_id'] as String,
      qty: double.tryParse(json['qty'].toString()) ?? 0,
      unitCost: double.tryParse(json['unit_cost'].toString()) ?? 0,
      totalCost: double.tryParse(json['total_cost'].toString()) ?? 0,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      productName:
          (json['products'] as Map<String, dynamic>?)?['name'] as String?,
    );
  }
}
