import '../../domain/entities/product_variant.dart';

class ProductVariantModel {
  static ProductVariant fromJson(Map<String, dynamic> json) {
    final rawAttrs = json['attributes_json'];
    final attrs = rawAttrs is Map<String, dynamic> ? rawAttrs : <String, dynamic>{};

    return ProductVariant(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      variantName: json['variant_name'] as String,
      sku: json['sku'] as String,
      barcode: json['barcode'] as String?,
      costPrice: (json['cost_price'] as num).toDouble(),
      sellingPrice: (json['selling_price'] as num).toDouble(),
      weight: (json['weight'] as num?)?.toDouble(),
      attributes: attrs,
      isActive: json['is_active'] as bool,
    );
  }

  static Map<String, dynamic> toJson(ProductVariant v) {
    return {
      'product_id': v.productId,
      'variant_name': v.variantName,
      'sku': v.sku,
      if (v.barcode != null) 'barcode': v.barcode,
      'cost_price': v.costPrice,
      'selling_price': v.sellingPrice,
      if (v.weight != null) 'weight': v.weight,
      'attributes_json': v.attributes,
      'is_active': v.isActive,
    };
  }
}
