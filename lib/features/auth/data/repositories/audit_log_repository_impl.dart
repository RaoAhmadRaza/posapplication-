import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/auth_failure.dart';
import '../../../../core/error/supabase_error_mapper.dart';
import '../datasources/auth_remote_datasource.dart';
import '../../domain/repositories/audit_log_repository.dart';

final auditLogRepositoryProvider = Provider<AuditLogRepository>((ref) {
  return AuditLogRepositoryImpl(ref.read(authRemoteDataSourceProvider));
});

class AuditLogRepositoryImpl implements AuditLogRepository {
  final AuthRemoteDataSource _ds;

  AuditLogRepositoryImpl(this._ds);

  @override
  Future<List<Map<String, dynamic>>> loadAuditLogs() async {
    return _ds.loadAuditLogs();
  }

  @override
  Future<AuthFailure?> insertAuditLog({
    required String userId,
    required String action,
    required String entity,
    String? entityId,
    Map<String, dynamic>? newValues,
  }) async {
    try {
      await _ds.insertAuditLog(
        userId: userId,
        action: action,
        entity: entity,
        entityId: entityId,
        newValues: newValues,
      );
      return null;
    } catch (e) {
      debugPrint('[AuditLogRepository] insert failed: $e');
      return mapSupabaseFailure(e);
    }
  }
}
