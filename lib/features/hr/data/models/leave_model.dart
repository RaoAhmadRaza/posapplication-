import '../../domain/entities/leave.dart';

class LeaveModel {
  static Leave fromJson(Map<String, dynamic> json) {
    return Leave(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      employeeId: json['employee_id'] as String,
      type: parseType(json['type'] as String?),
      fromDate: DateTime.parse(json['from_date'] as String),
      toDate: DateTime.parse(json['to_date'] as String),
      days: double.tryParse(json['days'].toString()) ?? 0,
      status: parseStatus(json['status'] as String?),
      reason: json['reason'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      employeeName:
          (json['employees'] as Map<String, dynamic>?)?['name'] as String?,
    );
  }

  static String typeToDb(LeaveType t) => switch (t) {
        LeaveType.annual => 'ANNUAL',
        LeaveType.sick => 'SICK',
        LeaveType.unpaid => 'UNPAID',
        LeaveType.maternity => 'MATERNITY',
        LeaveType.paternity => 'PATERNITY',
        LeaveType.casual => 'CASUAL',
      };

  static LeaveType parseType(String? t) =>
      switch ((t ?? 'ANNUAL').toUpperCase()) {
        'ANNUAL' => LeaveType.annual,
        'SICK' => LeaveType.sick,
        'UNPAID' => LeaveType.unpaid,
        'MATERNITY' => LeaveType.maternity,
        'PATERNITY' => LeaveType.paternity,
        'CASUAL' => LeaveType.casual,
        _ => LeaveType.annual,
      };

  static String statusToDb(LeaveStatus s) => switch (s) {
        LeaveStatus.pending => 'PENDING',
        LeaveStatus.approved => 'APPROVED',
        LeaveStatus.rejected => 'REJECTED',
        LeaveStatus.cancelled => 'CANCELLED',
      };

  static LeaveStatus parseStatus(String? s) =>
      switch ((s ?? 'PENDING').toUpperCase()) {
        'PENDING' => LeaveStatus.pending,
        'APPROVED' => LeaveStatus.approved,
        'REJECTED' => LeaveStatus.rejected,
        'CANCELLED' => LeaveStatus.cancelled,
        _ => LeaveStatus.pending,
      };
}
