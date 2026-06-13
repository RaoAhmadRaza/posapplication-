import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/load_audit_logs.dart';

final securityLogsControllerProvider =
    NotifierProvider<SecurityLogsController, AsyncValue<List<Map<String, dynamic>>>>(
  SecurityLogsController.new,
);

class SecurityLogsController extends Notifier<AsyncValue<List<Map<String, dynamic>>>> {
  @override
  AsyncValue<List<Map<String, dynamic>>> build() => const AsyncValue.loading();

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final logs = await ref.read(loadAuditLogsUseCaseProvider).call();
      state = AsyncValue.data(logs);
    } catch (_) {
      state = AsyncValue.error('Could not load logs.', StackTrace.current);
    }
  }
}
