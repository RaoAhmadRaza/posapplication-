enum AccountType { asset, liability, equity, revenue, expense }

class Account {
  final String id;
  final String tenantId;
  final String code;
  final String name;
  final AccountType type;
  final String? parentId;
  final String? description;
  final bool isSystem;
  final bool isActive;
  final String? branchId;
  final double openingBalance;
  final double currentBalance;
  final DateTime createdAt;

  const Account({
    required this.id,
    required this.tenantId,
    required this.code,
    required this.name,
    required this.type,
    this.parentId,
    this.description,
    required this.isSystem,
    required this.isActive,
    this.branchId,
    required this.openingBalance,
    required this.currentBalance,
    required this.createdAt,
  });
}
