import '../../domain/entities/attendance.dart';

class AttendanceModel {
  static Attendance fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      employeeId: json['employee_id'] as String,
      date: DateTime.parse(json['date'] as String),
      shiftId: json['shift_id'] as String?,
      checkIn: json['check_in'] == null
          ? null
          : DateTime.tryParse(json['check_in'].toString()),
      checkOut: json['check_out'] == null
          ? null
          : DateTime.tryParse(json['check_out'].toString()),
      status: parseStatus(json['status'] as String?),
      lateMinutes: (json['late_minutes'] as num?)?.toInt() ?? 0,
      overtimeHours: double.tryParse(json['overtime_hours'].toString()) ?? 0,
      notes: json['notes'] as String?,
    );
  }

  static String statusToDb(AttendanceStatus s) => switch (s) {
        AttendanceStatus.present => 'PRESENT',
        AttendanceStatus.absent => 'ABSENT',
        AttendanceStatus.late => 'LATE',
        AttendanceStatus.halfDay => 'HALF_DAY',
        AttendanceStatus.onLeave => 'ON_LEAVE',
        AttendanceStatus.holiday => 'HOLIDAY',
      };

  static AttendanceStatus parseStatus(String? s) =>
      switch ((s ?? 'PRESENT').toUpperCase()) {
        'PRESENT' => AttendanceStatus.present,
        'ABSENT' => AttendanceStatus.absent,
        'LATE' => AttendanceStatus.late,
        'HALF_DAY' => AttendanceStatus.halfDay,
        'ON_LEAVE' => AttendanceStatus.onLeave,
        'HOLIDAY' => AttendanceStatus.holiday,
        _ => AttendanceStatus.present,
      };
}
