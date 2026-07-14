enum PayrollStatus { draft, calculated, approved, disbursed, cancelled }

enum PayrollItemStatus { pending, paid, held, cancelled }

class PayrollRun {
  final String id;
  final String tenantId;
  final String branchId;
  final String period;
  final DateTime startDate;
  final DateTime endDate;
  final PayrollStatus status;
  final int employeeCount;
  final double totalGross;
  final double totalDeductions;
  final double totalNet;
  final String? journalEntryId;

  const PayrollRun({
    required this.id,
    required this.tenantId,
    required this.branchId,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.employeeCount,
    required this.totalGross,
    required this.totalDeductions,
    required this.totalNet,
    this.journalEntryId,
  });
}

class PayrollItem {
  final String id;
  final String runId;
  final String employeeId;
  final double basic;
  final double overtimeHours;
  final double overtimeAmount;
  final double grossSalary;
  final double totalDeductions;
  final double netSalary;
  final PayrollItemStatus status;

  /// Display-only, from the embedded `employees(name)` join on load.
  final String? employeeName;

  const PayrollItem({
    required this.id,
    required this.runId,
    required this.employeeId,
    required this.basic,
    required this.overtimeHours,
    required this.overtimeAmount,
    required this.grossSalary,
    required this.totalDeductions,
    required this.netSalary,
    required this.status,
    this.employeeName,
  });
}
