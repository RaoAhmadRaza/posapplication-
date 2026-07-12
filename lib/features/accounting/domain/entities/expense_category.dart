class ExpenseCategory {
  final String id;
  final String tenantId;
  final String name;
  final String? accountId;
  final String? parentId;
  final String? description;
  final bool isActive;
  final DateTime createdAt;

  const ExpenseCategory({
    required this.id,
    required this.tenantId,
    required this.name,
    this.accountId,
    this.parentId,
    this.description,
    required this.isActive,
    required this.createdAt,
  });
}
