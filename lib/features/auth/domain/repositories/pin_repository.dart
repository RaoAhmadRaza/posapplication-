import '../../../../core/error/auth_failure.dart';

abstract class PinRepository {
  /// null = updated; non-null = mapped failure (caller logs it).
  Future<AuthFailure?> updatePinHash(String userId, String? hash);

  /// Returns the server pin_hash (nullable) on success, or a mapped failure.
  Future<(String?, AuthFailure?)> getServerPinHash(String userId);
}
