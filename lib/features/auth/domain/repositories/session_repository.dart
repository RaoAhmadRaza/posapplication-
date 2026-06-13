abstract class SessionRepository {
  Future<List<Map<String, dynamic>>> listSessions();
  Future<void> revokeSession(String userId);
}
