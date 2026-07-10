import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/login_throttle_repository_impl.dart';
import '../../features/auth/domain/repositories/login_throttle_repository.dart';
import '../error/auth_failure.dart';
import '../supabase.dart';

const _storage = FlutterSecureStorage();
const _attemptsPrefix = 'login_attempts_';
const _lockedUntilPrefix = 'login_locked_';

class LoginThrottleService {
  LoginThrottleService({LoginThrottleRepository? repo})
      : _repo =
            repo ?? LoginThrottleRepositoryImpl(AuthRemoteDataSource(supabase));

  static final instance = LoginThrottleService();

  final LoginThrottleRepository _repo;

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

    final (data, failure) = await _repo.incrementFailedLogin(email);
    if (failure != null) {
      // Server counter is best-effort; the local secure-storage throttle above
      // already recorded this attempt. Log, don't block the login error path.
      debugPrint('[LoginThrottle] increment failed: ${failure.message}');
      return;
    }
    if (data != null && data['locked'] == true) {
      throw AccountLockedException(
        data['locked_until'] as String? ?? DateTime.now().toUtc().toIso8601String(),
      );
    }
  }

  Future<void> reset(String email) async {
    await _storage.delete(key: _key(email, _attemptsPrefix));
    await _storage.delete(key: _key(email, _lockedUntilPrefix));
    final failure = await _repo.resetFailedLogin(email);
    if (failure != null) {
      debugPrint('[LoginThrottle] reset failed: ${failure.message}');
    }
  }
}
