import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(supabase);
});

class AuthRemoteDataSource {
  final SupabaseClient _client;

  AuthRemoteDataSource(this._client);

  Future<(Map<String, dynamic>, bool needsConfirmation)> signUp({
    required String email,
    required String password,
    String? fullName,
    String? businessName,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        if (fullName != null) 'full_name': fullName,
        if (businessName != null) 'business_name': businessName,
      },
    );
    final needsConfirmation = res.session == null;
    final data = <String, dynamic>{};
    if (res.user != null) {
      data['id'] = res.user!.id;
      data['email'] = res.user!.email;
    }
    return (data, needsConfirmation);
  }

  Future<(Map<String, dynamic>, bool needsConfirmation)> signIn({
    required String email,
    required String password,
  }) async {
    final res = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final data = <String, dynamic>{};
    if (res.user != null) {
      data['id'] = res.user!.id;
      data['email'] = res.user!.email;
    }
    return (data, false);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> verifyEmailOtp({
    required String email,
    required String code,
  }) async {
    await _client.auth.verifyOTP(email: email, token: code, type: OtpType.signup);
  }

  Future<void> requestPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<void> verifyRecoveryOtp({
    required String email,
    required String code,
  }) async {
    await _client.auth.verifyOTP(email: email, token: code, type: OtpType.recovery);
  }

  Future<void> setNewPassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> resendSignupCode(String email) async {
    await _client.auth.resend(type: OtpType.signup, email: email);
  }

  Future<void> resendRecoveryCode(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  Stream<AuthState> watchAuthState() {
    return _client.auth.onAuthStateChange;
  }

  Future<Map<String, dynamic>> loadProfile(String userId) async {
    return await _client
        .from('users')
        .select('full_name, email, role_id, tenant_id, roles(name), tenants(name)')
        .eq('id', userId)
        .single();
  }

  Session? get currentSession => _client.auth.currentSession;

  Future<List<Map<String, dynamic>>> loadPermissions(String roleId) async {
    final list = await _client
        .from('permissions')
        .select('module, action, branch_scope, granted')
        .eq('role_id', roleId);
    return List<Map<String, dynamic>>.from(list);
  }

  Future<List<Map<String, dynamic>>> loadUserBranches(String userId) async {
    final list = await _client
        .from('user_branch_assignments')
        .select('is_default, branches(id, name, code, is_main, currency)')
        .eq('user_id', userId);
    return List<Map<String, dynamic>>.from(list);
  }

  Future<List<Map<String, dynamic>>> loadDevices() async {
    final list = await _client
        .from('devices')
        .select('id, device_name, device_model, os_info, trust_level, authorized, last_seen_at, authorized_at, authorized_by')
        .order('last_seen_at', ascending: false);
    return List<Map<String, dynamic>>.from(list);
  }

  Future<void> approveDevice(String deviceId, String authorizedBy) async {
    await _client.from('devices').update({
      'authorized': true,
      'trust_level': 'TRUSTED',
      'authorized_at': DateTime.now().toUtc().toIso8601String(),
      'authorized_by': authorizedBy,
    }).eq('id', deviceId);
  }

  Future<void> revokeDevice(String deviceId) async {
    await _client.from('devices').update({
      'authorized': false,
      'trust_level': 'REVOKED',
    }).eq('id', deviceId);
  }

  Future<List<Map<String, dynamic>>> loadAuditLogs() async {
    final list = await _client
        .from('audit_logs')
        .select('action, entity, created_at, user_id')
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(list);
  }

  Future<void> insertAuditLog({
    required String userId,
    required String action,
    required String entity,
    String? entityId,
    Map<String, dynamic>? newValues,
  }) async {
    await _client.from('audit_logs').insert({
      'user_id': userId,
      'action': action,
      'entity': entity,
      'entity_id': entityId,
      'new_values': newValues,
    });
  }

  Future<Map<String, dynamic>?> incrementFailedLogin(String email) async {
    final res =
        await _client.rpc('increment_failed_login', params: {'p_email': email});
    return res as Map<String, dynamic>?;
  }

  Future<void> resetFailedLogin(String email) async {
    await _client.rpc('reset_failed_login', params: {'p_email': email});
  }

  Future<void> registerDevice({
    required String tenantId,
    required String userId,
    required String deviceName,
    required String deviceModel,
    required String osInfo,
    required String fingerprintHash,
  }) async {
    await _client.from('devices').upsert({
      'tenant_id': tenantId,
      'user_id': userId,
      'device_name': deviceName,
      'device_model': deviceModel,
      'os_info': osInfo,
      'fingerprint_hash': fingerprintHash,
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'tenant_id,fingerprint_hash');
  }

  Future<void> updatePinHash(String userId, String? hash) async {
    await _client.from('users').update({'pin_hash': hash}).eq('id', userId);
  }

  Future<String?> selectPinHash(String userId) async {
    final data = await _client
        .from('users')
        .select('pin_hash')
        .eq('id', userId)
        .single();
    return data['pin_hash'] as String?;
  }
}
