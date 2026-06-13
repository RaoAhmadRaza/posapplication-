import '../supabase.dart';
import 'audit_service.dart';

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

class MfaService {
  static const instance = MfaService._();
  const MfaService._();

  Future<MfaEnrollResult> enroll() async {
    final res = await supabase.auth.mfa.enroll(issuer: 'Lumina POS');
    return MfaEnrollResult(
      factorId: res.id,
      qrCodeUri: res.totp!.qrCode,
      secret: res.totp!.secret,
    );
  }

  Future<String> challenge(String factorId) async {
    final res = await supabase.auth.mfa.challenge(factorId: factorId);
    return res.id;
  }

  Future<bool> verify({
    required String factorId,
    required String challengeId,
    required String code,
  }) async {
    try {
      await supabase.auth.mfa.verify(
        factorId: factorId,
        challengeId: challengeId,
        code: code,
      );
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('mfa_configs').upsert({
        'user_id': userId,
        'enabled': true,
      }, onConflict: 'user_id');
      AuditService.instance.log(action: 'MFA_ENROLL', entity: 'auth');
      return true;
    } catch (_) {
      return false;
    }
  }

  bool needsAal2() {
    final res = supabase.auth.mfa.getAuthenticatorAssuranceLevel();
    if (res.currentLevel == null || res.nextLevel == null) return false;
    return res.currentLevel!.name == 'aal1' &&
        res.nextLevel!.name == 'aal2';
  }

  Future<String?> getEnrolledFactorId() async {
    final res = await supabase.auth.mfa.listFactors();
    for (final f in res.all) {
      if (f.status.name == 'verified') {
        return f.id;
      }
    }
    return null;
  }

  Future<void> unenroll(String factorId) async {
    try {
      await supabase.auth.mfa.unenroll(factorId);
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('mfa_configs').upsert({
        'user_id': userId,
        'enabled': false,
      }, onConflict: 'user_id');
    } catch (_) {}
  }
}
