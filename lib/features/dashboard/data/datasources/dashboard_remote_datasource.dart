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
}
