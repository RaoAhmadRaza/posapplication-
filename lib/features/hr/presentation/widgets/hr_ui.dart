import 'package:flutter/widgets.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/attendance.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/leave.dart';
import '../../domain/entities/payroll.dart';

/// Shared presentation helpers for the HR module: status labels, [AppPill]
/// tone mappers, salary/date/initials formatting. Replaces the old
/// `hr_status_ui.dart` (which drove hand-rolled badges off static `AppColors`);
/// everything here is theme-aware via `AppPill`/`context.lum`.

// ── Labels ──────────────────────────────────────────────────────────────────

const employeeStatusLabels = {
  EmployeeStatus.active: 'Active',
  EmployeeStatus.onLeave: 'On leave',
  EmployeeStatus.suspended: 'Suspended',
  EmployeeStatus.terminated: 'Terminated',
  EmployeeStatus.resigned: 'Resigned',
};

const salaryTypeLabels = {
  SalaryType.monthly: 'Monthly',
  SalaryType.daily: 'Daily',
  SalaryType.hourly: 'Hourly',
};

/// Compact suffix shown after a base-salary figure (e.g. `45,000 /mo`).
const salaryUnitLabels = {
  SalaryType.monthly: '/mo',
  SalaryType.daily: '/day',
  SalaryType.hourly: '/hr',
};

const attendanceStatusLabels = {
  AttendanceStatus.present: 'Present',
  AttendanceStatus.absent: 'Absent',
  AttendanceStatus.late: 'Late',
  AttendanceStatus.halfDay: 'Half day',
  AttendanceStatus.onLeave: 'On leave',
  AttendanceStatus.holiday: 'Holiday',
};

/// Single-letter cell marker for the monthly attendance grid.
const attendanceStatusShort = {
  AttendanceStatus.present: 'P',
  AttendanceStatus.absent: 'A',
  AttendanceStatus.late: 'L',
  AttendanceStatus.halfDay: 'H',
  AttendanceStatus.onLeave: 'V',
  AttendanceStatus.holiday: '·',
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

const payrollStatusLabels = {
  PayrollStatus.draft: 'Draft',
  PayrollStatus.calculated: 'Calculated',
  PayrollStatus.approved: 'Approved',
  PayrollStatus.disbursed: 'Disbursed',
  PayrollStatus.cancelled: 'Cancelled',
};

// ── Pill tones ──────────────────────────────────────────────────────────────

AppPillTone employeeStatusTone(EmployeeStatus s) => switch (s) {
      EmployeeStatus.active => AppPillTone.success,
      EmployeeStatus.onLeave => AppPillTone.warning,
      EmployeeStatus.suspended => AppPillTone.warning,
      EmployeeStatus.terminated => AppPillTone.danger,
      EmployeeStatus.resigned => AppPillTone.neutral,
    };

AppPillTone attendanceStatusTone(AttendanceStatus s) => switch (s) {
      AttendanceStatus.present => AppPillTone.success,
      AttendanceStatus.absent => AppPillTone.danger,
      AttendanceStatus.late => AppPillTone.warning,
      AttendanceStatus.halfDay => AppPillTone.warning,
      AttendanceStatus.onLeave => AppPillTone.lumen,
      AttendanceStatus.holiday => AppPillTone.neutral,
    };

AppPillTone leaveStatusTone(LeaveStatus s) => switch (s) {
      LeaveStatus.pending => AppPillTone.warning,
      LeaveStatus.approved => AppPillTone.success,
      LeaveStatus.rejected => AppPillTone.danger,
      LeaveStatus.cancelled => AppPillTone.neutral,
    };

AppPillTone payrollStatusTone(PayrollStatus s) => switch (s) {
      PayrollStatus.draft => AppPillTone.neutral,
      PayrollStatus.calculated => AppPillTone.lumen,
      PayrollStatus.approved => AppPillTone.warning,
      PayrollStatus.disbursed => AppPillTone.success,
      PayrollStatus.cancelled => AppPillTone.danger,
    };

/// Whether an app login is linked to this employee. `userId` is written by
/// consume_staff_invite when the invitee redeems, so this reads "an account
/// exists", not "an invite was sent" — a pending invite still shows no login.
/// Lumen, not success: the employee-status pill beside it is already green.
(String, AppPillTone) employeeLoginUi(String? userId) => userId == null
    ? ('No login', AppPillTone.neutral)
    : ('Login', AppPillTone.lumen);

// ── Attendance cell colours (grid + tab markers use a tinted tile, not a pill)─

/// (background, foreground) pair for an attendance marker tile in the current
/// theme. Mirrors [attendanceStatusTone] but returns raw colours for the grid.
(Color, Color) attendanceCellColors(BuildContext context, AttendanceStatus s) {
  final lum = context.lum;
  return switch (s) {
    AttendanceStatus.present => (lum.successSoft, lum.successText),
    AttendanceStatus.absent => (lum.dangerSoft, lum.dangerText),
    AttendanceStatus.late => (lum.warningSoft, lum.warningText),
    AttendanceStatus.halfDay => (lum.warningSoft, lum.warningText),
    AttendanceStatus.onLeave => (lum.accentSoft, lum.accentPress),
    AttendanceStatus.holiday => (lum.g100, lum.g500),
  };
}

// ── Text helpers ─────────────────────────────────────────────────────────────

/// Up to two uppercase initials from a name; '?' when blank.
String hrInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}
