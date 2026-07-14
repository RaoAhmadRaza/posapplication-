enum AttendanceStatus { present, absent, late, halfDay, onLeave, holiday }

class Attendance {
  final String id;
  final String tenantId;
  final String employeeId;
  final DateTime date;
  final String? shiftId;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final AttendanceStatus status;
  final int lateMinutes;
  final double overtimeHours;
  final String? notes;

  const Attendance({
    required this.id,
    required this.tenantId,
    required this.employeeId,
    required this.date,
    this.shiftId,
    this.checkIn,
    this.checkOut,
    required this.status,
    required this.lateMinutes,
    required this.overtimeHours,
    this.notes,
  });
}
