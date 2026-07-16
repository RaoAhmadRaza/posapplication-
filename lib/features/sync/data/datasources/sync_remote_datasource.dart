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
}
