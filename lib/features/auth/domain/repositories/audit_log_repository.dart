import '../../../../core/error/auth_failure.dart';

abstract class AuditLogRepository {
  Future<List<Map<String, dynamic>>> loadAuditLogs();

  /// null = written; non-null = mapped failure (caller logs it).
  Future<AuthFailure?> insertAuditLog({
    required String userId,
    required String action,
    required String entity,
    String? entityId,
    Map<String, dynamic>? newValues,
  });
}
