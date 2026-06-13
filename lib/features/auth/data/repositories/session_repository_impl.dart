import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../datasources/session_remote_datasource.dart';
import '../../domain/repositories/session_repository.dart';

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepositoryImpl(ref.read(sessionRemoteDataSourceProvider));
});

class SessionRepositoryImpl implements SessionRepository {
  final SessionRemoteDataSource _ds;

  SessionRepositoryImpl(this._ds);

  @override
  Future<List<Map<String, dynamic>>> listSessions() async {
    return _ds.listSessions();
  }

  @override
  Future<void> revokeSession(String userId) async {
    return _ds.revokeSession(userId);
  }
}
