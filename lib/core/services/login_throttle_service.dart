import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../error/auth_failure.dart';

// macOS: legacy keychain (not data-protection) so writes work under the sandbox
// without a keychain-access-groups entitlement. Must match the other secure-
// storage sites (see pin_service.dart). Fixes -34018.
const _storage = FlutterSecureStorage(
  mOptions: MacOsOptions(usesDataProtectionKeychain: false),
);
const _attemptsPrefix = 'login_attempts_';
const _lockedUntilPrefix = 'login_locked_';

/// Local, device-side login throttle. The server-side counter
/// (increment_failed_login / reset_failed_login) was removed in Phase 1.5A —
/// it was anon-callable and a DoS surface; Supabase Auth rate-limits sign-in
/// natively. Lockout is now enforced purely from secure storage.
class LoginThrottleService {
  LoginThrottleService();

  static final instance = LoginThrottleService();

  static const maxAttempts = 5;
  static const baseCooldown = 30;

  String _key(String email, String prefix) => '$prefix${_hash(email)}';

  String _hash(String s) => base64Url.encode(s.codeUnits).replaceAll('=', '');

  Future<int> _currentAttempts(String email) async {
    final v = await _storage.read(key: _key(email, _attemptsPrefix));
    return int.tryParse(v ?? '0') ?? 0;
  }

  int cooldownForAttempt(int attempts) {
    if (attempts <= maxAttempts) return 0;
    var duration = baseCooldown;
    for (int i = maxAttempts + 1; i < attempts; i++) {
      duration = (duration * 2).clamp(0, 480);
    }
    return duration;
  }

  Future<(bool canAttempt, int remainingSeconds)> canAttempt(String email) async {
    final lockedUntil = await _storage.read(key: _key(email, _lockedUntilPrefix));
    if (lockedUntil == null) return (true, 0);
    final lockDt = DateTime.tryParse(lockedUntil);
    if (lockDt == null) return (true, 0);
    final remaining = lockDt.difference(DateTime.now().toUtc()).inSeconds;
    if (remaining <= 0) {
      await _storage.delete(key: _key(email, _lockedUntilPrefix));
      return (true, 0);
    }
    return (false, remaining);
  }

  Future<void> recordFailure(String email) async {
    final attempts = await _currentAttempts(email) + 1;
    await _storage.write(
      key: _key(email, _attemptsPrefix),
      value: attempts.toString(),
    );

    final cooldown = cooldownForAttempt(attempts);
    if (cooldown > 0) {
      final lockUntil = DateTime.now().toUtc().add(Duration(seconds: cooldown));
      await _storage.write(
        key: _key(email, _lockedUntilPrefix),
        value: lockUntil.toIso8601String(),
      );
      // Local lockout kicked in. Surface it exactly as the removed server path
      // did, so SignInController's `on AccountLockedException` catch is unchanged.
      throw AccountLockedException(lockUntil.toIso8601String());
    }
  }

  Future<void> reset(String email) async {
    await _storage.delete(key: _key(email, _attemptsPrefix));
    await _storage.delete(key: _key(email, _lockedUntilPrefix));
  }
}
