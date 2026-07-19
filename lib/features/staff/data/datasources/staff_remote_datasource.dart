import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase.dart';

final staffRemoteDataSourceProvider = Provider<StaffRemoteDataSource>((ref) {
  return StaffRemoteDataSource(supabase);
});

/// All Supabase calls for the staff feature. RPCs are tenant-scoped server-side
/// (auth_tenant_id); the one raw select (branches) resolves tenant from the
/// caller's own users row.
class StaffRemoteDataSource {
  StaffRemoteDataSource(this._client);
  final SupabaseClient _client;

  String? _cachedTenantId;
  Future<String> _tenantId() async {
    if (_cachedTenantId != null) return _cachedTenantId!;
    final data = await _client.from('users').select('tenant_id').single();
    _cachedTenantId = data['tenant_id'] as String;
    return _cachedTenantId!;
  }

  Future<List<Map<String, dynamic>>> listInvites() async {
    final res = await _client.rpc('list_staff_invites');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createInvite({
    required String roleId,
    required List<String> branchIds,
    String? fullName,
    String? email,
    String? employeeId,
    required int expiresInHours,
  }) async {
    final res = await _client.rpc('create_staff_invite', params: {
      'p_role_id': roleId,
      'p_branch_ids': branchIds,
      'p_full_name': fullName,
      'p_email': email,
      'p_employee_id': employeeId,
      'p_expires_in_hours': expiresInHours,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> regenerateInvite(String inviteId) async {
    final res = await _client
        .rpc('regenerate_staff_invite', params: {'p_invite_id': inviteId});
    return Map<String, dynamic>.from(res as Map);
  }

  Future<void> revokeInvite(String inviteId) async {
    await _client.rpc('revoke_staff_invite', params: {'p_invite_id': inviteId});
  }

  Future<void> releaseAbandoned(String inviteId) async {
    await _client
        .rpc('release_abandoned_invite', params: {'p_invite_id': inviteId});
  }

  Future<List<Map<String, dynamic>>> listRoles() async {
    final res = await _client.rpc('list_tenant_roles');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> listPermissionCatalog() async {
    final res = await _client.rpc('list_permission_catalog');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<String> createRole({
    required String name,
    String? description,
    required int hierarchyLevel,
    required List<Map<String, dynamic>> permissions,
  }) async {
    final res = await _client.rpc('create_tenant_role', params: {
      'p_name': name,
      'p_description': description,
      'p_hierarchy_level': hierarchyLevel,
      'p_permissions': permissions,
    });
    return res as String;
  }

  Future<void> updateRolePermissions(
      String roleId, List<Map<String, dynamic>> permissions) async {
    await _client.rpc('update_role_permissions',
        params: {'p_role_id': roleId, 'p_permissions': permissions});
  }

  // Current granted permissions for a role, to prefill the edit form. Plain
  // RLS-scoped read (perm tenant read) — no RPC needed.
  Future<List<Map<String, dynamic>>> loadRolePermissions(String roleId) async {
    final res = await _client
        .from('permissions')
        .select('module, action, branch_scope')
        .eq('role_id', roleId)
        .eq('granted', true);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> listUsers() async {
    final res = await _client.rpc('list_tenant_users');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> updateUserRole(String userId, String roleId) async {
    await _client.rpc('update_user_role',
        params: {'p_user_id': userId, 'p_role_id': roleId});
  }

  Future<List<Map<String, dynamic>>> listBranches() async {
    return _client
        .from('branches')
        .select('id, name, is_main')
        .eq('tenant_id', await _tenantId())
        .order('is_main', ascending: false)
        .order('name');
  }

  // ---- invitee side (pre-auth) ----

  /// Anon-callable: validate a scanned token before the invitee sets credentials.
  Future<Map<String, dynamic>> validateInvite(String token) async {
    final res = await _client.rpc('validate_staff_invite', params: {'p_token': token});
    return Map<String, dynamic>.from(res as Map);
  }

  /// Redeem: sign up with the invite token in metadata. handle_new_user consumes
  /// it and joins the existing tenant. NEVER sends business_name (that = ADMIN branch).
  /// Returns the email if email confirmation is still pending (no session yet).
  Future<String?> redeemInvite({
    required String email,
    required String password,
    required String token,
    String? fullName,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'invite_token': token,
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
      },
    );
    return res.session == null ? email : null;
  }
}
