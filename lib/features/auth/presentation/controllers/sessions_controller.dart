import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/realtime/subscribe_reload.dart';
import '../../domain/usecases/list_sessions.dart';
import '../../domain/usecases/revoke_session.dart';

final sessionsControllerProvider =
    NotifierProvider<SessionsController, AsyncValue<List<Map<String, dynamic>>>>(
  SessionsController.new,
);

class SessionsController extends Notifier<AsyncValue<List<Map<String, dynamic>>>> {
  @override
  AsyncValue<List<Map<String, dynamic>>> build() {
    // RLS on sessions is self-only, so this signals on the current user's own
    // session changes (e.g. a second device signing in / this device being
    // revoked); load() refetches the full tenant list via the edge function.
    subscribeReload(ref, 'sessions', load);
    return const AsyncValue.loading();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final sessions = await ref.read(listSessionsUseCaseProvider).call();
      state = AsyncValue.data(sessions);
    } catch (_) {
      state = AsyncValue.error('Could not load sessions.', StackTrace.current);
    }
  }

  Future<void> revoke(String userId) async {
    try {
      await ref.read(revokeSessionUseCaseProvider).call(userId);
      await load();
    } catch (_) {
      state = AsyncValue.error('Failed to revoke session.', StackTrace.current);
    }
  }
}
