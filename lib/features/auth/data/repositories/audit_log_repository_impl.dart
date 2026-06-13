import 'package:flutter_riverpod/flutter_riverpod.dart';
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
}
