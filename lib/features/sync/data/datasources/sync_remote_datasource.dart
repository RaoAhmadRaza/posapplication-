import 'package:supabase_flutter/supabase_flutter.dart';

/// The ONLY place the Supabase client is touched for the sync feature.
/// sync_pull_reference(p_since timestamptz) returns a single jsonb Map with keys:
/// watermark, products[], variants[], customers[], payment_methods[], tax_rules[], stock[].
class SyncRemoteDataSource {
  SyncRemoteDataSource(this._client);
  final SupabaseClient _client;

  Future<Map<String, dynamic>> pullReference(String? since) async {
    final result =
        await _client.rpc('sync_pull_reference', params: {'p_since': since});
    return result as Map<String, dynamic>; // RPC returns a single Map, never .first
  }

  /// Enqueue a local intent into the server outbox (idempotent on the key).
  /// Returns {outbox_id, status}.
  Future<Map<String, dynamic>> pushIntent({
    required String idempotencyKey,
    required String branchId,
    required Map<String, dynamic> payload,
    required String clientCreatedAt,
    required String localRef,
    String? deviceId,
  }) async {
    final result = await _client.rpc('sync_push_intent', params: {
      'p_idempotency_key': idempotencyKey,
      'p_branch_id': branchId,
      'p_payload': payload,
      'p_client_created_at': clientCreatedAt,
      'p_local_ref': localRef,
      'p_device_id': deviceId,
    });
    return result as Map<String, dynamic>;
  }

  /// Replay one intent through create_sale.
  /// Returns {applied|skipped, invoice_id?, error?, terminal?}.
  Future<Map<String, dynamic>> replayIntent(String outboxId) async {
    final result = await _client
        .rpc('sync_replay_sale_intent', params: {'p_outbox_id': outboxId});
    return result as Map<String, dynamic>;
  }

  /// After apply/skip: the real invoice for this key (id + number). ≤1 by uq_invoices_idem.
  Future<Map<String, dynamic>?> invoiceForKey(String idempotencyKey) async {
    return _client
        .from('invoices')
        .select('id, invoice_number')
        .eq('idempotency_key', idempotencyKey)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> loadOpenExceptions() async {
    final rows = await _client
        .from('sync_exceptions')
        .select(
            'id, outbox_id, error_code, error_detail, payload_json, status, created_at')
        .eq('status', 'OPEN')
        .order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> resolveException(String id, String note) async {
    await _client
        .rpc('resolve_sync_exception', params: {'p_id': id, 'p_note': note});
  }
}
