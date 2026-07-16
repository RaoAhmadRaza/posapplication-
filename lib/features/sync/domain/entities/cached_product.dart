/// A product row from the Class A reference cache (sync_pull_reference.products),
/// persisted locally for offline lookup + price resolution.
class CachedProduct {
  const CachedProduct({
    required this.id,
    required this.sku,
    required this.name,
    this.barcode,
    required this.sellingPrice,
    this.minSellingPrice,
    required this.taxRate,
    required this.taxInclusive,
    required this.isActive,
    required this.updatedAt,
  });

  final String id;
  final String sku;
  final String name;
  final String? barcode;
  final double sellingPrice;
  final double? minSellingPrice;
  final double taxRate;
  final bool taxInclusive;
  final bool isActive;
  final String updatedAt;
}
