import '../../domain/entities/account.dart';

class AccountModel {
  static Account fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      type: _parseType(json['type'] as String?),
      parentId: json['parent_id'] as String?,
      description: json['description'] as String?,
      isSystem: json['is_system'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      branchId: json['branch_id'] as String?,
      openingBalance: double.tryParse(json['opening_balance'].toString()) ?? 0,
      currentBalance: double.tryParse(json['current_balance'].toString()) ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static String typeToDb(AccountType t) => switch (t) {
    AccountType.asset => 'ASSET',
    AccountType.liability => 'LIABILITY',
    AccountType.equity => 'EQUITY',
    AccountType.revenue => 'REVENUE',
    AccountType.expense => 'EXPENSE',
  };

  static AccountType _parseType(String? s) {
    return switch ((s ?? 'ASSET').toUpperCase()) {
      'ASSET' => AccountType.asset,
      'LIABILITY' => AccountType.liability,
      'EQUITY' => AccountType.equity,
      'REVENUE' => AccountType.revenue,
      'EXPENSE' => AccountType.expense,
      _ => AccountType.asset,
    };
  }
}
