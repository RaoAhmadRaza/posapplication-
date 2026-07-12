import '../../domain/entities/expense_category.dart';

class ExpenseCategoryModel {
  static ExpenseCategory fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      name: json['name'] as String,
      accountId: json['account_id'] as String?,
      parentId: json['parent_id'] as String?,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
