import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase.dart';

final reportingRemoteDataSourceProvider =
    Provider<ReportingRemoteDataSource>((ref) {
  return ReportingRemoteDataSource(supabase);
});

/// All Supabase calls for the reporting feature live here (reads over the MV RPCs).
class ReportingRemoteDataSource {
  final SupabaseClient _client;
  ReportingRemoteDataSource(this._client);

  Future<List<Map<String, dynamic>>> _rows(
    String rpc, [
    Map<String, dynamic>? params,
  ]) async {
    final result = await _client.rpc(rpc, params: params ?? const {});
    return (result as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> inventoryValuation() =>
      _rows('report_inventory_valuation');

  Future<List<Map<String, dynamic>>> productPerformance() =>
      _rows('report_product_performance');

  Future<List<Map<String, dynamic>>> customerAging() =>
      _rows('report_customer_aging');

  Future<List<Map<String, dynamic>>> supplierAging() =>
      _rows('report_supplier_aging');

  Future<List<Map<String, dynamic>>> dailySales({String? from, String? to}) =>
      _rows('report_daily_sales', {'p_from': from, 'p_to': to});

  // report_schedules + ai_recommendations are RLS-capable (own-tenant) → direct table reads.
  Future<List<Map<String, dynamic>>> listSchedules() async {
    final result = await _client
        .from('report_schedules')
        .select()
        .order('created_at', ascending: false);
    return (result as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> upsertSchedule({
    String? id,
    required String reportType,
    required String name,
    required String frequency,
    required Map<String, dynamic> filters,
    required List<String> recipients,
    required String format,
    required bool active,
  }) async {
    await _client.rpc('upsert_report_schedule', params: {
      'p_id': id,
      'p_report_type': reportType,
      'p_name': name,
      'p_frequency': frequency,
      'p_filters': filters,
      'p_recipients': recipients,
      'p_format': format,
      'p_active': active,
    });
  }

  Future<List<Map<String, dynamic>>> pendingRecommendations() async {
    final result = await _client
        .from('ai_recommendations')
        .select()
        .eq('status', 'PENDING')
        .order('created_at', ascending: false);
    return (result as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> actOnRecommendation(String id, bool accept) async {
    await _client.rpc('act_on_recommendation',
        params: {'p_id': id, 'p_accept': accept});
  }
}
