import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../domain/entities/attendance.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/leave.dart';

const employeeStatusLabels = {
  EmployeeStatus.active: 'Active',
  EmployeeStatus.onLeave: 'On Leave',
  EmployeeStatus.suspended: 'Suspended',
  EmployeeStatus.terminated: 'Terminated',
  EmployeeStatus.resigned: 'Resigned',
};

const salaryTypeLabels = {
  SalaryType.monthly: 'Monthly',
  SalaryType.daily: 'Daily',
  SalaryType.hourly: 'Hourly',
};

Color employeeStatusColor(EmployeeStatus s) => switch (s) {
      EmployeeStatus.active => AppColors.success,
      EmployeeStatus.onLeave => AppColors.warning,
      EmployeeStatus.suspended => AppColors.warning,
      EmployeeStatus.terminated => AppColors.destructive,
      EmployeeStatus.resigned => AppColors.textMuted,
    };

const attendanceStatusLabels = {
  AttendanceStatus.present: 'Present',
  AttendanceStatus.absent: 'Absent',
  AttendanceStatus.late: 'Late',
  AttendanceStatus.halfDay: 'Half day',
  AttendanceStatus.onLeave: 'On leave',
  AttendanceStatus.holiday: 'Holiday',
};

/// Single-letter cell marker for the monthly grid.
const attendanceStatusShort = {
  AttendanceStatus.present: 'P',
  AttendanceStatus.absent: 'A',
  AttendanceStatus.late: 'L',
  AttendanceStatus.halfDay: 'H',
  AttendanceStatus.onLeave: 'V',
  AttendanceStatus.holiday: '·',
};

Color attendanceStatusColor(AttendanceStatus s) => switch (s) {
      AttendanceStatus.present => AppColors.success,
      AttendanceStatus.absent => AppColors.destructive,
      AttendanceStatus.late => AppColors.warning,
      AttendanceStatus.halfDay => AppColors.warning,
      AttendanceStatus.onLeave => AppColors.accent,
      AttendanceStatus.holiday => AppColors.textMuted,
    };

const leaveTypeLabels = {
  LeaveType.annual: 'Annual',
  LeaveType.sick: 'Sick',
  LeaveType.unpaid: 'Unpaid',
  LeaveType.maternity: 'Maternity',
  LeaveType.paternity: 'Paternity',
  LeaveType.casual: 'Casual',
};

const leaveStatusLabels = {
  LeaveStatus.pending: 'Pending',
  LeaveStatus.approved: 'Approved',
  LeaveStatus.rejected: 'Rejected',
  LeaveStatus.cancelled: 'Cancelled',
};

Color leaveStatusColor(LeaveStatus s) => switch (s) {
      LeaveStatus.pending => AppColors.warning,
      LeaveStatus.approved => AppColors.success,
      LeaveStatus.rejected => AppColors.destructive,
      LeaveStatus.cancelled => AppColors.textMuted,
    };

class EmployeeStatusBadge extends StatelessWidget {
  const EmployeeStatusBadge({super.key, required this.status});
  final EmployeeStatus status;

  @override
  Widget build(BuildContext context) {
    final color = employeeStatusColor(status);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        employeeStatusLabels[status]!,
        style: AppTypography.caption
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
