enum LeaveType { annual, sick, unpaid, maternity, paternity, casual }

enum LeaveStatus { pending, approved, rejected, cancelled }

class Leave {
  final String id;
  final String tenantId;
  final String employeeId;
  final LeaveType type;
  final DateTime fromDate;
  final DateTime toDate;
  final double days;
  final LeaveStatus status;
  final String? reason;
  final String? rejectionReason;

  /// Display-only, from the embedded `employees(name)` join on load.
  final String? employeeName;

  const Leave({
    required this.id,
    required this.tenantId,
    required this.employeeId,
    required this.type,
    required this.fromDate,
    required this.toDate,
    required this.days,
    required this.status,
    this.reason,
    this.rejectionReason,
    this.employeeName,
  });

  bool get isPending => status == LeaveStatus.pending;
}
