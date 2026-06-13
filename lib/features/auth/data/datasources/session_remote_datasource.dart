import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/supabase.dart';

final sessionRemoteDataSourceProvider = Provider<SessionRemoteDataSource>((ref) {
  return SessionRemoteDataSource(supabase);
});

class SessionRemoteDataSource {
  final dynamic _client;
  SessionRemoteDataSource(this._client);

  Future<List<Map<String, dynamic>>> listSessions() async {
    final res = await _client.functions.invoke('list-sessions');
    final data = res.data as Map<String, dynamic>;
    final sessions = data['sessions'] as List<dynamic>? ?? [];
    return sessions.cast<Map<String, dynamic>>();
  }

  Future<void> revokeSession(String userId) async {
    await _client.functions.invoke('revoke-session', body: {'userId': userId});
  }
}
