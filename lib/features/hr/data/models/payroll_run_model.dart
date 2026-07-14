import '../../domain/entities/payroll.dart';

class PayrollRunModel {
  static PayrollRun fromJson(Map<String, dynamic> json) {
    return PayrollRun(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      branchId: json['branch_id'] as String,
      period: json['period'] as String,
      startDate: DateTime.parse(json['period_start'] as String),
      endDate: DateTime.parse(json['period_end'] as String),
      status: parseStatus(json['status'] as String?),
      employeeCount: (json['employee_count'] as num?)?.toInt() ?? 0,
      totalGross: double.tryParse(json['total_gross'].toString()) ?? 0,
      totalDeductions:
          double.tryParse(json['total_deductions'].toString()) ?? 0,
      totalNet: double.tryParse(json['total_net'].toString()) ?? 0,
      journalEntryId: json['journal_entry_id'] as String?,
    );
  }

  static PayrollStatus parseStatus(String? s) =>
      switch ((s ?? 'DRAFT').toUpperCase()) {
        'DRAFT' => PayrollStatus.draft,
        'CALCULATED' => PayrollStatus.calculated,
        'APPROVED' => PayrollStatus.approved,
        'DISBURSED' => PayrollStatus.disbursed,
        'CANCELLED' => PayrollStatus.cancelled,
        _ => PayrollStatus.draft,
      };
}
