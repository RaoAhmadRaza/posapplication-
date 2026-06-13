class Category {
  final String id;
  final String tenantId;
  final String name;
  final String slug;
  final String? parentId;
  final String? description;
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;

  const Category({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.slug,
    this.parentId,
    this.description,
    this.imageUrl,
    required this.sortOrder,
    required this.isActive,
  });
}
