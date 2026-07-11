import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/audit_service.dart';
import '../../../../core/supabase.dart';

class MfaEnrollResult {
  final String factorId;
  final String qrCodeUri;
  final String secret;
  const MfaEnrollResult({
    required this.factorId,
    required this.qrCodeUri,
    required this.secret,
  });
}

final mfaRemoteDataSourceProvider = Provider<MfaRemoteDataSource>((ref) {
  return MfaRemoteDataSource(supabase);
});

class MfaRemoteDataSource {
  final SupabaseClient _client;

  MfaRemoteDataSource(this._client);

  Future<MfaEnrollResult> enroll() async {
    final res = await _client.auth.mfa.enroll(issuer: 'Lumina POS');
    return MfaEnrollResult(
      factorId: res.id,
      qrCodeUri: res.totp!.qrCode,
      secret: res.totp!.secret,
    );
  }

  Future<String> challenge(String factorId) async {
    final res = await _client.auth.mfa.challenge(factorId: factorId);
    return res.id;
  }

  /// Verifies the code. Throws on failure (mapped to a typed failure in the
  /// repository — success side-effects run only when verify() itself succeeds).
  Future<void> verify({
    required String factorId,
    required String challengeId,
    required String code,
  }) async {
    await _client.auth.mfa.verify(
      factorId: factorId,
      challengeId: challengeId,
      code: code,
    );
    final userId = _client.auth.currentUser!.id;
    await _client.from('mfa_configs').upsert({
      'user_id': userId,
      'enabled': true,
    }, onConflict: 'user_id');
    AuditService.instance.log(action: 'MFA_ENROLL', entity: 'auth');
  }

  bool needsAal2() {
    final res = _client.auth.mfa.getAuthenticatorAssuranceLevel();
    if (res.currentLevel == null || res.nextLevel == null) return false;
    return res.currentLevel!.name == 'aal1' && res.nextLevel!.name == 'aal2';
  }

  Future<String?> getEnrolledFactorId() async {
    final res = await _client.auth.mfa.listFactors();
    for (final f in res.all) {
      if (f.status.name == 'verified') {
        return f.id;
      }
    }
    return null;
  }

  Future<void> unenroll(String factorId) async {
    await _client.auth.mfa.unenroll(factorId);
    final userId = _client.auth.currentUser!.id;
    await _client.from('mfa_configs').upsert({
      'user_id': userId,
      'enabled': false,
    }, onConflict: 'user_id');
  }
}
