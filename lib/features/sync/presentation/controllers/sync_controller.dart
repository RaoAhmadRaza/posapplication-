import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/sale_intent.dart';
import '../../domain/failures/sync_failure.dart';
import '../../domain/usecases/enqueue_sale_intent.dart';
import '../../domain/usecases/pull_reference.dart';
import '../../domain/usecases/read_cache.dart';

/// Count of intents still awaiting replay. Rebuilds on demand; the POS refreshes
/// it after enqueuing an offline sale.
class OutboxCountController extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final (n, failure) = await ref.read(pendingIntentCountUseCaseProvider).call();
    if (failure != null) throw failure;
    return n;
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      final (n, failure) =
          await ref.read(pendingIntentCountUseCaseProvider).call();
      if (failure != null) throw failure;
      return n;
    });
  }
}

final outboxCountProvider =
    AsyncNotifierProvider<OutboxCountController, int>(OutboxCountController.new);

/// Mutations: pull the reference cache, enqueue an offline sale. Returns a
/// typed failure (never swallowed) and invalidates the affected providers.
class SyncActions {
  SyncActions(this._ref);
  final Ref _ref;

  Future<SyncFailure?> pull() => _ref.read(pullReferenceUseCaseProvider).call();

  Future<(SaleIntent?, SyncFailure?)> enqueueSale({
    required String branchId,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> payments,
    String? notes,
    String? sessionId,
  }) async {
    final (intent, failure) = await _ref.read(enqueueSaleIntentUseCaseProvider).call(
          branchId: branchId,
          items: items,
          payments: payments,
          notes: notes,
          sessionId: sessionId,
        );
    if (failure == null) {
      await _ref.read(outboxCountProvider.notifier).refresh();
    }
    return (intent, failure);
  }
}

final syncActionsProvider = Provider<SyncActions>((ref) => SyncActions(ref));
