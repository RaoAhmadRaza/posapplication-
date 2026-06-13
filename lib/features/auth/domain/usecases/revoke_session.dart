import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/session_repository_impl.dart';
import '../repositories/session_repository.dart';

class RevokeSession {
  final SessionRepository _repo;
  RevokeSession(this._repo);

  Future<void> call(String userId) async {
    return _repo.revokeSession(userId);
  }
}

final revokeSessionUseCaseProvider = Provider<RevokeSession>((ref) {
  return RevokeSession(ref.read(sessionRepositoryProvider));
});
