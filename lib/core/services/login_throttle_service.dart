import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../error/auth_failure.dart';
import '../supabase.dart';

const _storage = FlutterSecureStorage();
const _attemptsPrefix = 'login_attempts_';
const _lockedUntilPrefix = 'login_locked_';

class LoginThrottleService {
  static const instance = LoginThrottleService._();
  const LoginThrottleService._();

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
    }

    final res = await supabase.rpc('increment_failed_login', params: {'p_email': email});
    final data = res as Map<String, dynamic>?;
    if (data != null && data['locked'] == true) {
      throw AccountLockedException(
        data['locked_until'] as String? ?? DateTime.now().toUtc().toIso8601String(),
      );
    }
  }

  Future<void> reset(String email) async {
    await _storage.delete(key: _key(email, _attemptsPrefix));
    await _storage.delete(key: _key(email, _lockedUntilPrefix));
    try {
      await supabase.rpc('reset_failed_login', params: {'p_email': email});
    } catch (_) {}
  }
}
