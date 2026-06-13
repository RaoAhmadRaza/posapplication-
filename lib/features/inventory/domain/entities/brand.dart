class Brand {
  final String id;
  final String tenantId;
  final String name;
  final String slug;
  final String? logoUrl;
  final String? description;
  final bool isActive;

  const Brand({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.slug,
    this.logoUrl,
    this.description,
    required this.isActive,
  });
}
