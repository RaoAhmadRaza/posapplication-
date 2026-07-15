import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase.dart';

final dashboardRemoteDataSourceProvider = Provider<DashboardRemoteDataSource>((ref) {
  return DashboardRemoteDataSource(supabase);
});

class DashboardRemoteDataSource {
  final SupabaseClient _client;

  DashboardRemoteDataSource(this._client);

  Future<Map<String, dynamic>> loadSummary({
    String? branchId,
    String? from,
    String? to,
  }) async {
    final result = await _client.rpc('dashboard_summary', params: {
      'p_branch_id': branchId,
      'p_from': from,
      'p_to': to,
    });
    return result as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> drilldown(
    String rpc,
    Map<String, dynamic> params,
  ) async {
    final result = await _client.rpc(rpc, params: params);
    return (result as List<dynamic>).cast<Map<String, dynamic>>();
  }

  /// Reads this user's saved KPI layout (ui_preferences.dashboard_layout_json).
  /// Returns null when there is no row / nothing saved yet (own-row RLS).
  Future<List<dynamic>?> loadKpiLayout() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _client
        .from('ui_preferences')
        .select('dashboard_layout_json')
        .eq('user_id', uid)
        .maybeSingle();
    return row?['dashboard_layout_json'] as List<dynamic>?;
  }

  /// Upserts this user's KPI layout via upsert_ui_preferences. Other preference
  /// fields are left untouched (RPC coalesce-merges nulls). Returns the RPC Map.
  Future<Map<String, dynamic>> saveKpiLayout(
    List<Map<String, dynamic>> layout,
  ) async {
    final result = await _client.rpc('upsert_ui_preferences', params: {
      'p_theme': null,
      'p_language': null,
      'p_sidebar_collapsed': null,
      'p_default_branch_id': null,
      'p_dashboard_layout': layout,
      'p_table_preferences': null,
      'p_pos_layout': null,
      'p_preferences': null,
    });
    return result as Map<String, dynamic>;
  }
}
