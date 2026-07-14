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
}
