import '../../domain/entities/shift.dart';

class ShiftModel {
  static Shift fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      name: json['name'] as String,
      startTime: _hhmm(json['start_time'] as String?),
      endTime: _hhmm(json['end_time'] as String?),
      graceMinutes: (json['grace_minutes'] as num?)?.toInt() ?? 15,
      breakMinutes: (json['break_minutes'] as num?)?.toInt() ?? 60,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  /// Postgres `time` serializes as 'HH:mm:ss' — trim to 'HH:mm' for display.
  static String _hhmm(String? t) {
    if (t == null || t.length < 5) return t ?? '';
    return t.substring(0, 5);
  }
}
