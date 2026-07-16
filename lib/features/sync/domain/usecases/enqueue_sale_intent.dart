import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../entities/sale_intent.dart';
import '../failures/sync_failure.dart';
import '../repositories/sync_repository.dart';
import '../../data/repositories/sync_repository_impl.dart';

/// Builds the offline SALE intent (client-generated idempotency_key = the whole
/// replay contract, true client_created_at, provisional local_ref) and appends
/// it to the outbox. Does NOT replay — that is D7.2.
class EnqueueSaleIntent {
  EnqueueSaleIntent(this._repo);
  final SyncRepository _repo;
  static const _uuid = Uuid();

  Future<(SaleIntent?, SyncFailure?)> call({
    required String branchId,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> payments,
    String? notes,
    String? sessionId,
  }) async {
    final key = _uuid.v4();
    // Human-readable provisional ref for the paper receipt (NOT an invoice number —
    // a device cannot call the server-side row-locked next_number counter).
    final localRef = 'OFF-${key.substring(0, 8).toUpperCase()}';
    final intent = SaleIntent(
      id: _uuid.v4(),
      idempotencyKey: key,
      clientCreatedAt: DateTime.now().toUtc().toIso8601String(),
      localRef: localRef,
      payload: {
        'branch_id': branchId,
        'customer_id': null, // offline is cash-only by construction (no credit → no customer)
        'items': items,
        'payments': payments,
        'notes': notes,
        'session_id': sessionId,
      },
    );
    final failure = await _repo.enqueueSaleIntent(intent);
    if (failure != null) return (null, failure);
    return (intent, null);
  }
}

final enqueueSaleIntentUseCaseProvider = Provider<EnqueueSaleIntent>(
  (ref) => EnqueueSaleIntent(ref.read(syncRepositoryProvider)),
);
