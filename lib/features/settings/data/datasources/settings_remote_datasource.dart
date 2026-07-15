import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase.dart';

final settingsRemoteDataSourceProvider =
    Provider<SettingsRemoteDataSource>((ref) {
  return SettingsRemoteDataSource(supabase);
});

/// The ONE Supabase surface for the settings feature. No Supabase calls live
/// outside this class. RPCs return a single Map (or a scalar for
/// resolve_payment_account); tenant/audit ids are set server-side by the RPCs,
/// direct-CRUD tables (payment_methods) are RLS-gated on settings:update.
class SettingsRemoteDataSource {
  final SupabaseClient _client;
  SettingsRemoteDataSource(this._client);

  String? _cachedTenantId;
  Future<String> _tenantId() async {
    if (_cachedTenantId != null) return _cachedTenantId!;
    final data = await _client.from('users').select('tenant_id').single();
    _cachedTenantId = data['tenant_id'] as String;
    return _cachedTenantId!;
  }

  // ---- tenant settings (tenants.settings_json) ----
  Future<Map<String, dynamic>> loadTenantSettings() async {
    return _client
        .from('tenants')
        .select('name, settings_json')
        .eq('id', await _tenantId())
        .single();
  }

  /// Returns the merged settings_json Map (update_tenant_settings shallow-merges).
  Future<Map<String, dynamic>> updateTenantSettings(
    Map<String, dynamic> patch,
  ) async {
    final result =
        await _client.rpc('update_tenant_settings', params: {'p_patch': patch});
    return (result as Map).cast<String, dynamic>();
  }

  // ---- branches ----
  Future<List<Map<String, dynamic>>> loadBranches() async {
    return _client
        .from('branches')
        .select('id, name, code, city, country, currency, timezone, is_active, is_main')
        .eq('tenant_id', await _tenantId())
        .order('is_main', ascending: false)
        .order('name');
  }

  Future<Map<String, dynamic>> updateBranchSettings({
    required String branchId,
    String? name,
    String? city,
    String? country,
    String? currency,
    String? timezone,
    bool? isActive,
  }) async {
    return await _client.rpc('update_branch_settings', params: {
      'p_branch_id': branchId,
      'p_name': name,
      'p_city': city,
      'p_country': country,
      'p_currency': currency,
      'p_timezone': timezone,
      'p_is_active': isActive,
    }) as Map<String, dynamic>;
  }

  // ---- payment methods (direct CRUD, RLS settings:update) ----
  static const _pmCols =
      'id, code, name, is_active, is_system, requires_reference, sort_order, bank_account_id';

  Future<List<Map<String, dynamic>>> loadPaymentMethods() async {
    return _client
        .from('payment_methods')
        .select(_pmCols)
        .eq('tenant_id', await _tenantId())
        .isFilter('deleted_at', null)
        .order('sort_order');
  }

  Future<Map<String, dynamic>> createPaymentMethod(
    Map<String, dynamic> data,
  ) async {
    final list = await _client
        .from('payment_methods')
        .insert({...data, 'tenant_id': await _tenantId()})
        .select(_pmCols);
    return list.first;
  }

  Future<Map<String, dynamic>> updatePaymentMethod(
    String id,
    Map<String, dynamic> data,
  ) async {
    final list = await _client
        .from('payment_methods')
        .update(data)
        .eq('id', id)
        .select(_pmCols);
    return list.first;
  }

  Future<void> softDeletePaymentMethod(String id) async {
    await _client
        .from('payment_methods')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  /// Scalar RPC: returns the GL account CODE a method posts to today.
  Future<String> resolvePaymentAccount({
    required String method,
    String? bankAccountId,
  }) async {
    final result = await _client.rpc('resolve_payment_account', params: {
      'p_tenant_id': await _tenantId(),
      'p_method': method,
      'p_bank_account_id': bankAccountId,
    });
    return result as String;
  }

  Future<List<Map<String, dynamic>>> loadBankAccounts() async {
    return _client
        .from('bank_accounts')
        .select('id, account_name, bank_name')
        .eq('tenant_id', await _tenantId())
        .eq('is_active', true)
        .isFilter('deleted_at', null)
        .order('account_name');
  }

  // ---- number series (read-only) ----
  Future<List<Map<String, dynamic>>> loadNumberSeries() async {
    return _client
        .from('number_series')
        .select('type, prefix, padding, current_number, fiscal_year_reset')
        .eq('tenant_id', await _tenantId())
        .order('type');
  }

  // ---- preferences (ui_preferences) ----
  Future<Map<String, dynamic>?> loadUiPreferences() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    return _client
        .from('ui_preferences')
        .select('theme, language, default_branch_id')
        .eq('user_id', uid)
        .maybeSingle();
  }

  Future<Map<String, dynamic>> upsertUiPreferences({
    String? theme,
    String? language,
    String? defaultBranchId,
  }) async {
    final result = await _client.rpc('upsert_ui_preferences', params: {
      'p_theme': theme,
      'p_language': language,
      'p_sidebar_collapsed': null,
      'p_default_branch_id': defaultBranchId,
      'p_dashboard_layout': null,
      'p_table_preferences': null,
      'p_pos_layout': null,
      'p_preferences': null,
    });
    return result as Map<String, dynamic>;
  }
}
