import '../../domain/entities/pricing_tier.dart';

class PricingTierModel {
  static PricingTier fromJson(Map<String, dynamic> json) {
    return PricingTier(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      tierName: json['tier_name'] as String,
      customerGroupId: json['customer_group_id'] as String?,
      minQty: json['min_qty'] as int,
      maxQty: json['max_qty'] as int?,
      unitPrice: (json['unit_price'] as num).toDouble(),
      discountPct: (json['discount_pct'] as num?)?.toDouble(),
      validFrom: json['valid_from'] as String?,
      validUntil: json['valid_until'] as String?,
      isActive: json['is_active'] as bool,
    );
  }

  static Map<String, dynamic> toJson(PricingTier t) {
    return {
      'product_id': t.productId,
      'tier_name': t.tierName,
      if (t.customerGroupId != null) 'customer_group_id': t.customerGroupId,
      'min_qty': t.minQty,
      if (t.maxQty != null) 'max_qty': t.maxQty,
      'unit_price': t.unitPrice,
      if (t.discountPct != null) 'discount_pct': t.discountPct,
      if (t.validFrom != null) 'valid_from': t.validFrom,
      if (t.validUntil != null) 'valid_until': t.validUntil,
      'is_active': t.isActive,
    };
  }
}
