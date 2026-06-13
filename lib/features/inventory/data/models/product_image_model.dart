import '../../domain/entities/product_image.dart';

class ProductImageModel {
  static ProductImage fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      url: json['url'] as String,
      altText: json['alt_text'] as String?,
      sortOrder: json['sort_order'] as int,
      isPrimary: json['is_primary'] as bool,
    );
  }

  static Map<String, dynamic> toJson(ProductImage img) {
    return {
      'product_id': img.productId,
      'url': img.url,
      if (img.altText != null) 'alt_text': img.altText,
      'sort_order': img.sortOrder,
      'is_primary': img.isPrimary,
    };
  }
}
