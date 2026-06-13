import '../../domain/entities/category.dart';

class CategoryModel {
  static Category fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      parentId: json['parent_id'] as String?,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      sortOrder: json['sort_order'] as int,
      isActive: json['is_active'] as bool,
    );
  }

  static Map<String, dynamic> toJson(Category c) {
    return {
      'name': c.name,
      'slug': c.slug,
      if (c.parentId != null) 'parent_id': c.parentId,
      if (c.description != null) 'description': c.description,
      if (c.imageUrl != null) 'image_url': c.imageUrl,
      'sort_order': c.sortOrder,
      'is_active': c.isActive,
    };
  }
}
