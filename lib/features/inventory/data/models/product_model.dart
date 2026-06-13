import '../../domain/entities/product.dart';

ProductType _productTypeFromString(String? s) {
  switch (s) {
    case 'SERIALIZED':
      return ProductType.serialized;
    case 'SERVICE':
      return ProductType.service;
    case 'COMPOSITE':
      return ProductType.composite;
    default:
      return ProductType.standard;
  }
}

String _productTypeToString(ProductType t) {
  switch (t) {
    case ProductType.serialized:
      return 'SERIALIZED';
    case ProductType.service:
      return 'SERVICE';
    case ProductType.composite:
      return 'COMPOSITE';
    case ProductType.standard:
      return 'STANDARD';
  }
}

ProductStatus _productStatusFromString(String? s) {
  switch (s) {
    case 'INACTIVE':
      return ProductStatus.inactive;
    case 'DISCONTINUED':
      return ProductStatus.discontinued;
    default:
      return ProductStatus.active;
  }
}

String _productStatusToString(ProductStatus s) {
  switch (s) {
    case ProductStatus.inactive:
      return 'INACTIVE';
    case ProductStatus.discontinued:
      return 'DISCONTINUED';
    case ProductStatus.active:
      return 'ACTIVE';
  }
}

class ProductModel {
  static Product fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    List<String>? tags;
    if (rawTags is List) {
      tags = rawTags.cast<String>();
    }

    return Product(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      sku: json['sku'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      barcode: json['barcode'] as String?,
      type: _productTypeFromString(json['type'] as String?),
      categoryId: json['category_id'] as String?,
      brandId: json['brand_id'] as String?,
      unitOfMeasure: json['unit_of_measure'] as String? ?? 'PCS',
      costPrice: (json['cost_price'] as num).toDouble(),
      sellingPrice: (json['selling_price'] as num).toDouble(),
      minSellingPrice: (json['min_selling_price'] as num?)?.toDouble(),
      wholesalePrice: (json['wholesale_price'] as num?)?.toDouble(),
      taxRate: (json['tax_rate'] as num).toDouble(),
      taxInclusive: json['tax_inclusive'] as bool,
      reorderPoint: json['reorder_point'] as int,
      reorderQty: json['reorder_qty'] as int,
      weight: (json['weight'] as num?)?.toDouble(),
      isActive: json['is_active'] as bool,
      status: _productStatusFromString(json['status'] as String?),
      imageUrl: json['image_url'] as String?,
      tags: tags,
    );
  }

  static Map<String, dynamic> toJson(Product p) {
    return {
      'sku': p.sku,
      'name': p.name,
      if (p.description != null) 'description': p.description,
      if (p.barcode != null) 'barcode': p.barcode,
      'type': _productTypeToString(p.type),
      if (p.categoryId != null) 'category_id': p.categoryId,
      if (p.brandId != null) 'brand_id': p.brandId,
      'unit_of_measure': p.unitOfMeasure,
      'cost_price': p.costPrice,
      'selling_price': p.sellingPrice,
      if (p.minSellingPrice != null) 'min_selling_price': p.minSellingPrice,
      if (p.wholesalePrice != null) 'wholesale_price': p.wholesalePrice,
      'tax_rate': p.taxRate,
      'tax_inclusive': p.taxInclusive,
      'reorder_point': p.reorderPoint,
      'reorder_qty': p.reorderQty,
      if (p.weight != null) 'weight': p.weight,
      'is_active': p.isActive,
      'status': _productStatusToString(p.status),
      if (p.imageUrl != null) 'image_url': p.imageUrl,
      if (p.tags != null) 'tags': p.tags,
    };
  }
}
