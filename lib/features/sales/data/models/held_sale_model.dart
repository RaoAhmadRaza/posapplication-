import '../../domain/entities/held_sale.dart';

class HeldSaleModel {
  static HeldSale fromJson(Map<String, dynamic> json) {
    final cartJson = json['cart_json'] is Map
        ? Map<String, dynamic>.from(json['cart_json'] as Map)
        : Map<String, dynamic>.from(json['cart_json'] is List ? {} : <String, dynamic>{});
    final lines = (cartJson['lines'] as List<dynamic>?) ?? [];
    return HeldSale(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      branchId: json['branch_id'] as String,
      sessionId: json['session_id'] as String?,
      customerId: json['customer_id'] as String?,
      customerName: json['customer_name'] as String? ?? cartJson['customerName'] as String?,
      cartJson: cartJson,
      label: json['label'] as String,
      itemCount: lines.length,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
