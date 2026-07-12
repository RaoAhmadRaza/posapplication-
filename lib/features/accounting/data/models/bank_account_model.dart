import '../../domain/entities/bank_account.dart';

class BankAccountModel {
  static BankAccount fromJson(Map<String, dynamic> json) {
    return BankAccount(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      branchId: json['branch_id'] as String?,
      accountName: json['account_name'] as String,
      bankName: json['bank_name'] as String?,
      accountNumber: json['account_number'] as String?,
      iban: json['iban'] as String?,
      swiftCode: json['swift_code'] as String?,
      currency: json['currency'] as String?,
      openingBalance: double.tryParse(json['opening_balance'].toString()) ?? 0,
      currentBalance: double.tryParse(json['current_balance'].toString()) ?? 0,
      chartAccountId: json['chart_account_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
