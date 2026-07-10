import '../../../../core/error/auth_failure.dart';

abstract class LoginThrottleRepository {
  /// Returns the RPC result Map on success (caller inspects `locked`), or a
  /// mapped failure on error (caller logs it — server counter is best-effort).
  Future<(Map<String, dynamic>?, AuthFailure?)> incrementFailedLogin(
      String email);

  Future<AuthFailure?> resetFailedLogin(String email);
}
