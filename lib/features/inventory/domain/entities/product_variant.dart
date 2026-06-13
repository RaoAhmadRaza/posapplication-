class ProductVariant {
  final String id;
  final String productId;
  final String variantName;
  final String sku;
  final String? barcode;
  final double costPrice;
  final double sellingPrice;
  final double? weight;
  final Map<String, dynamic> attributes;
  final bool isActive;

  const ProductVariant({
    required this.id,
    required this.productId,
    required this.variantName,
    required this.sku,
    this.barcode,
    required this.costPrice,
    required this.sellingPrice,
    this.weight,
    required this.attributes,
    required this.isActive,
  });
}
