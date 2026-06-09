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
}
