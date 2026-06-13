import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/session_repository_impl.dart';
import '../repositories/session_repository.dart';

class ListSessions {
  final SessionRepository _repo;
  ListSessions(this._repo);

  Future<List<Map<String, dynamic>>> call() async {
    return _repo.listSessions();
  }
}

final listSessionsUseCaseProvider = Provider<ListSessions>((ref) {
  return ListSessions(ref.read(sessionRepositoryProvider));
});
