class Shift {
  final String id;
  final String tenantId;
  final String name;

  /// 'HH:mm' 24-hour, as stored (Postgres `time`).
  final String startTime;
  final String endTime;
  final int graceMinutes;
  final int breakMinutes;
  final bool isActive;

  const Shift({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.graceMinutes,
    required this.breakMinutes,
    required this.isActive,
  });
}
