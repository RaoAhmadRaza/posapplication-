abstract class AuditLogRepository {
  Future<List<Map<String, dynamic>>> loadAuditLogs();
}
