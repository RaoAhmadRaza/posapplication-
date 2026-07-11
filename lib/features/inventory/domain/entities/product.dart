enum ProductType { standard, serialized, service, composite }

enum ProductStatus { active, inactive, discontinued }

class Product {
  final String id;
  final String tenantId;
  final String sku;
  final String name;
  final String? description;
  final String? barcode;
  final ProductType type;
  final String? categoryId;
  final String? brandId;
  final String unitOfMeasure;
  final double costPrice;
  final double sellingPrice;
  final double? minSellingPrice;
  final double? wholesalePrice;
  final double taxRate;
  final bool taxInclusive;
  final int reorderPoint;
  final int reorderQty;
  final double? weight;
  final bool isActive;
  final ProductStatus status;
  final String? imageUrl;
  final List<String>? tags;
  final double? qtyOnHand;

  const Product({
    required this.id,
    required this.tenantId,
    required this.sku,
    required this.name,
    this.description,
    this.barcode,
    required this.type,
    this.categoryId,
    this.brandId,
    required this.unitOfMeasure,
    required this.costPrice,
    required this.sellingPrice,
    this.minSellingPrice,
    this.wholesalePrice,
    required this.taxRate,
    required this.taxInclusive,
    required this.reorderPoint,
    required this.reorderQty,
    this.weight,
    required this.isActive,
    required this.status,
    this.imageUrl,
    this.tags,
    this.qtyOnHand,
  });

  Product copyWith({double? qtyOnHand}) => Product(
    id: id,
    tenantId: tenantId,
    sku: sku,
    name: name,
    description: description,
    barcode: barcode,
    type: type,
    categoryId: categoryId,
    brandId: brandId,
    unitOfMeasure: unitOfMeasure,
    costPrice: costPrice,
    sellingPrice: sellingPrice,
    minSellingPrice: minSellingPrice,
    wholesalePrice: wholesalePrice,
    taxRate: taxRate,
    taxInclusive: taxInclusive,
    reorderPoint: reorderPoint,
    reorderQty: reorderQty,
    weight: weight,
    isActive: isActive,
    status: status,
    imageUrl: imageUrl,
    tags: tags,
    qtyOnHand: qtyOnHand ?? this.qtyOnHand,
  );
}
