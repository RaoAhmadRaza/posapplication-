import '../../../../core/error/auth_failure.dart';
import '../../data/datasources/mfa_remote_datasource.dart';

abstract class MfaRepository {
  Future<(MfaEnrollResult?, AuthFailure?)> enroll();
  Future<(String?, AuthFailure?)> challenge(String factorId);

  /// null = success, [InvalidOtpFailure] = wrong/expired code,
  /// [MfaTransientFailure] = network/unknown (retryable).
  Future<AuthFailure?> verify({
    required String factorId,
    required String challengeId,
    required String code,
  });

  bool needsAal2();
  Future<(String?, AuthFailure?)> getEnrolledFactorId();
  Future<AuthFailure?> unenroll(String factorId);
}
