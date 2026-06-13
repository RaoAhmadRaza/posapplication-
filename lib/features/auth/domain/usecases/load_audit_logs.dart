import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/audit_log_repository_impl.dart';
import '../repositories/audit_log_repository.dart';

class LoadAuditLogs {
  final AuditLogRepository _repo;
  LoadAuditLogs(this._repo);

  Future<List<Map<String, dynamic>>> call() async {
    return _repo.loadAuditLogs();
  }
}

final loadAuditLogsUseCaseProvider = Provider<LoadAuditLogs>((ref) {
  return LoadAuditLogs(ref.read(auditLogRepositoryProvider));
});
