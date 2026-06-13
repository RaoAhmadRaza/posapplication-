class PricingTier {
  final String id;
  final String productId;
  final String tierName;
  final String? customerGroupId;
  final int minQty;
  final int? maxQty;
  final double unitPrice;
  final double? discountPct;
  final String? validFrom;
  final String? validUntil;
  final bool isActive;

  const PricingTier({
    required this.id,
    required this.productId,
    required this.tierName,
    this.customerGroupId,
    required this.minQty,
    this.maxQty,
    required this.unitPrice,
    this.discountPct,
    this.validFrom,
    this.validUntil,
    required this.isActive,
  });
}
