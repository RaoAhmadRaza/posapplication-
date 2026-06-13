class ProductImage {
  final String id;
  final String productId;
  final String url;
  final String? altText;
  final int sortOrder;
  final bool isPrimary;

  const ProductImage({
    required this.id,
    required this.productId,
    required this.url,
    this.altText,
    required this.sortOrder,
    required this.isPrimary,
  });
}
