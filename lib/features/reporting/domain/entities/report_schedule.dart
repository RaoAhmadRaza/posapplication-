/// A recurring scheduled report (report_schedules row).
class ReportSchedule {
  final String id;
  final String reportType;
  final String name;
  final String frequency; // DAILY | WEEKLY | MONTHLY
  final List<String> recipients;
  final String outputFormat; // PDF | EXCEL
  final Map<String, dynamic> filters;
  final bool isActive;
  final DateTime? nextRunAt;
  final DateTime? lastRunAt;

  const ReportSchedule({
    required this.id,
    required this.reportType,
    required this.name,
    required this.frequency,
    required this.recipients,
    required this.outputFormat,
    required this.filters,
    required this.isActive,
    this.nextRunAt,
    this.lastRunAt,
  });
}
