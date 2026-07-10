import 'package:flutter/foundation.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/audit_log_repository_impl.dart';
import '../../features/auth/domain/repositories/audit_log_repository.dart';
import '../supabase.dart';

class AuditService {
  AuditService({AuditLogRepository? repo})
      : _repo = repo ?? AuditLogRepositoryImpl(AuthRemoteDataSource(supabase));

  static final instance = AuditService();

  final AuditLogRepository _repo;

  void log({
    required String action,
    required String entity,
    String? entityId,
    Map<String, dynamic>? newValues,
  }) {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _write(userId, action, entity, entityId, newValues, 2);
  }

  Future<void> _write(
    String userId,
    String action,
    String entity,
    String? entityId,
    Map<String, dynamic>? newValues,
    int retries,
  ) async {
    final failure = await _repo.insertAuditLog(
      userId: userId,
      action: action,
      entity: entity,
      entityId: entityId,
      newValues: newValues,
    );
    if (failure == null) return;
    if (retries > 0) {
      _write(userId, action, entity, entityId, newValues, retries - 1);
    } else {
      debugPrint(
          '[AuditService] failed to write audit log: $action $entity — ${failure.message}');
    }
  }
}
