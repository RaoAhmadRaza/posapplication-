import '../../domain/entities/salary_advance.dart';

class SalaryAdvanceModel {
  static SalaryAdvance fromJson(Map<String, dynamic> json) {
    return SalaryAdvance(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      employeeId: json['employee_id'] as String,
      amount: double.tryParse(json['amount'].toString()) ?? 0,
      balance: double.tryParse(json['balance'].toString()) ?? 0,
      recoveryAmount:
          double.tryParse(json['recovery_amount'].toString()) ?? 0,
      disbursedAt: DateTime.parse(json['disbursed_at'] as String),
      fullyRecoveredAt: json['fully_recovered_at'] == null
          ? null
          : DateTime.tryParse(json['fully_recovered_at'].toString()),
      journalEntryId: json['journal_entry_id'] as String?,
      notes: json['notes'] as String?,
    );
  }
}
