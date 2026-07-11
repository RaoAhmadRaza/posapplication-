import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/auth_failure.dart';
import '../../domain/repositories/mfa_repository.dart';
import '../datasources/mfa_remote_datasource.dart';

final mfaRepositoryProvider = Provider<MfaRepository>((ref) {
  return MfaRepositoryImpl(ref.read(mfaRemoteDataSourceProvider));
});

class MfaRepositoryImpl implements MfaRepository {
  final MfaRemoteDataSource _ds;

  MfaRepositoryImpl(this._ds);

  /// Order matters: AuthRetryableFetchException is a subclass of AuthException,
  /// so it must be caught before the generic AuthException branch. Only a real
  /// AuthApiException (server rejected the code) becomes "Incorrect code".
  AuthFailure _mapError(Object e) {
    if (e is AuthRetryableFetchException) return MfaTransientFailure();
    if (e is AuthApiException) return InvalidOtpFailure();
    if (e is AuthException) return MfaTransientFailure();
    return MfaTransientFailure();
  }

  @override
  Future<(MfaEnrollResult?, AuthFailure?)> enroll() async {
    try {
      return (await _ds.enroll(), null);
    } catch (e) {
      debugPrint('[MfaRepository] enroll failed: $e');
      return (null, _mapError(e));
    }
  }

  @override
  Future<(String?, AuthFailure?)> challenge(String factorId) async {
    try {
      return (await _ds.challenge(factorId), null);
    } catch (e) {
      debugPrint('[MfaRepository] challenge failed: $e');
      return (null, _mapError(e));
    }
  }

  @override
  Future<AuthFailure?> verify({
    required String factorId,
    required String challengeId,
    required String code,
  }) async {
    try {
      await _ds.verify(
        factorId: factorId,
        challengeId: challengeId,
        code: code,
      );
      return null;
    } catch (e) {
      debugPrint('[MfaRepository] verify failed: $e');
      return _mapError(e);
    }
  }

  @override
  bool needsAal2() {
    try {
      return _ds.needsAal2();
    } catch (e) {
      debugPrint('[MfaRepository] needsAal2 failed: $e');
      return false;
    }
  }

  @override
  Future<(String?, AuthFailure?)> getEnrolledFactorId() async {
    try {
      return (await _ds.getEnrolledFactorId(), null);
    } catch (e) {
      debugPrint('[MfaRepository] getEnrolledFactorId failed: $e');
      return (null, _mapError(e));
    }
  }

  @override
  Future<AuthFailure?> unenroll(String factorId) async {
    try {
      await _ds.unenroll(factorId);
      return null;
    } catch (e) {
      debugPrint('[MfaRepository] unenroll failed: $e');
      return _mapError(e);
    }
  }
}
