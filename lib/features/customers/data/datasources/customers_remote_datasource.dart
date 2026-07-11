import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase.dart';

final customersRemoteDataSourceProvider =
    Provider<CustomersRemoteDataSource>((ref) {
  return CustomersRemoteDataSource(supabase);
});

class CustomersRemoteDataSource {
  final SupabaseClient _client;

  CustomersRemoteDataSource(this._client);

  String? _cachedTenantId;

  Future<String> _tenantId() async {
    if (_cachedTenantId != null) return _cachedTenantId!;
    final data = await _client.from('users').select('tenant_id').single();
    _cachedTenantId = data['tenant_id'] as String;
    return _cachedTenantId!;
  }

  String? get _userId => _client.auth.currentUser?.id;

  static const _cols = 'id, tenant_id, name, phone, phone_secondary, email,'
      ' address_line1, address_line2, city, state, postal_code, country,'
      ' tax_number, group_id, credit_limit, credit_terms, loyalty_points,'
      ' opening_balance, status, tags, notes, created_at';

  Future<List<Map<String, dynamic>>> loadCustomers({
    String? query,
    String? status,
  }) async {
    var q = _client.from('customers').select(_cols).isFilter('deleted_at', null);
    if (query != null && query.isNotEmpty) {
      q = q.or('name.ilike.*$query*,phone.ilike.*$query*');
    }
    if (status != null) {
      q = q.eq('status', status);
    }
    return q.order('name');
  }

  Future<Map<String, dynamic>> loadCustomer(String id) async {
    return _client.from('customers').select(_cols).eq('id', id).single();
  }

  Future<Map<String, dynamic>> insertCustomer(Map<String, dynamic> data) async {
    final payload = {
      ...data,
      'tenant_id': await _tenantId(),
      'created_by': _userId,
      'updated_by': _userId,
    };
    final list =
        await _client.from('customers').insert(payload).select(_cols);
    return list.first;
  }

  Future<Map<String, dynamic>> updateCustomer(
      String id, Map<String, dynamic> data) async {
    final payload = {...data, 'updated_by': _userId};
    final list = await _client
        .from('customers')
        .update(payload)
        .eq('id', id)
        .select(_cols);
    return list.first;
  }

  Future<void> softDeleteCustomer(String id) async {
    await _client.from('customers').update({
      'deleted_at': DateTime.now().toUtc().toIso8601String(),
      'updated_by': _userId,
    }).eq('id', id);
  }

  Future<Map<String, dynamic>> customerLedger(String customerId) async {
    final result = await _client
        .rpc('customer_ledger', params: {'p_customer_id': customerId});
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> receivablesAging() async {
    final result = await _client.rpc('receivables_aging');
    return result as Map<String, dynamic>;
  }
}
