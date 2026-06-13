import '../../domain/entities/brand.dart';

class BrandModel {
  static Brand fromJson(Map<String, dynamic> json) {
    return Brand(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      logoUrl: json['logo_url'] as String?,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool,
    );
  }

  static Map<String, dynamic> toJson(Brand b) {
    return {
      'name': b.name,
      'slug': b.slug,
      if (b.logoUrl != null) 'logo_url': b.logoUrl,
      if (b.description != null) 'description': b.description,
      'is_active': b.isActive,
    };
  }
}
