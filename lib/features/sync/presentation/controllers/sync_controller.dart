import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/outbox_entry.dart';
import '../../domain/entities/sale_intent.dart';
import '../../domain/entities/sync_exception.dart';
import '../../domain/failures/sync_failure.dart';
import '../../domain/repositories/sync_repository.dart';
import '../../data/repositories/sync_repository_impl.dart';
import '../../domain/usecases/drain_outbox.dart';
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

/// Drain the outbox on reconnect / on demand. A single in-flight guard keeps the
/// drain SERIAL even if reconnect + manual trigger fire together.
class DrainActions {
  DrainActions(this._ref);
  final Ref _ref;
  bool _draining = false;

  Future<DrainSummary?> drainNow() async {
    if (_draining) return null;
    _draining = true;
    try {
      final (summary, failure) = await _ref.read(drainOutboxUseCaseProvider).call();
      await _ref.read(outboxCountProvider.notifier).refresh();
      _ref.invalidate(syncExceptionsProvider);
      _ref.invalidate(outboxIntentsProvider);
      _ref.invalidate(lastSyncProvider);
      return failure != null ? null : summary;
    } finally {
      _draining = false;
    }
  }

  Future<SyncFailure?> resolveException(String id, String note) async {
    final failure = await _ref.read(resolveSyncExceptionUseCaseProvider).call(id, note);
    if (failure == null) _ref.invalidate(syncExceptionsProvider);
    return failure;
  }
}

final drainActionsProvider = Provider<DrainActions>((ref) => DrainActions(ref));

final syncExceptionsProvider =
    FutureProvider.autoDispose<List<SyncException>>((ref) async {
  final (rows, failure) = await ref.read(loadSyncExceptionsUseCaseProvider).call();
  if (failure != null) throw failure;
  return rows;
});

final outboxIntentsProvider =
    FutureProvider.autoDispose<List<OutboxEntry>>((ref) async {
  final (rows, failure) = await ref.read(loadOutboxIntentsUseCaseProvider).call();
  if (failure != null) throw failure;
  return rows;
});

final lastSyncProvider = FutureProvider.autoDispose<String?>(
    (ref) => ref.read(syncRepositoryProvider).lastSyncAt());
