import '../../domain/entities/payroll.dart';

class PayrollItemModel {
  static PayrollItem fromJson(Map<String, dynamic> json) {
    return PayrollItem(
      id: json['id'] as String,
      runId: json['run_id'] as String,
      employeeId: json['employee_id'] as String,
      basic: double.tryParse(json['basic'].toString()) ?? 0,
      overtimeHours: double.tryParse(json['overtime_hours'].toString()) ?? 0,
      overtimeAmount:
          double.tryParse(json['overtime_amount'].toString()) ?? 0,
      grossSalary: double.tryParse(json['gross_salary'].toString()) ?? 0,
      totalDeductions:
          double.tryParse(json['total_deductions'].toString()) ?? 0,
      netSalary: double.tryParse(json['net_salary'].toString()) ?? 0,
      status: parseStatus(json['status'] as String?),
      allowances: _money(json['allowances_json']),
      deductions: _money(json['deductions_json']),
      employeeName:
          (json['employees'] as Map<String, dynamic>?)?['name'] as String?,
    );
  }

  /// jsonb object {component: amount} → `Map<String,double>` (display only).
  static Map<String, double> _money(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <String, double>{};
    raw.forEach((k, v) {
      final d = double.tryParse(v.toString());
      if (d != null && d != 0) out[k.toString()] = d;
    });
    return out;
  }

  static PayrollItemStatus parseStatus(String? s) =>
      switch ((s ?? 'PENDING').toUpperCase()) {
        'PENDING' => PayrollItemStatus.pending,
        'PAID' => PayrollItemStatus.paid,
        'HELD' => PayrollItemStatus.held,
        'CANCELLED' => PayrollItemStatus.cancelled,
        _ => PayrollItemStatus.pending,
      };
}
