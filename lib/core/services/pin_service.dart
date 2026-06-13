import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../supabase.dart';

const _storage = FlutterSecureStorage();
const _pinHashKey = 'pin_hash';
const _pinSaltKey = 'pin_salt';
const _biometricsKey = 'biometrics_enabled';

class PinService {
  static const instance = PinService._();
  const PinService._();

  Future<bool> hasPin() async {
    final hash = await _storage.read(key: _pinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hash(pin, salt);
    await _storage.write(key: _pinSaltKey, value: salt);
    await _storage.write(key: _pinHashKey, value: hash);

    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      try {
        await supabase.from('users').update({'pin_hash': hash}).eq('id', userId);
      } catch (_) {}
    }
  }

  Future<bool> verifyPin(String pin) async {
    final hash = await _storage.read(key: _pinHashKey);
    final salt = await _storage.read(key: _pinSaltKey);
    if (hash == null || salt == null) return false;
    return _hash(pin, salt) == hash;
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _pinSaltKey);
    await _storage.delete(key: _biometricsKey);

    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      try {
        await supabase.from('users').update({'pin_hash': null}).eq('id', userId);
      } catch (_) {}
    }
  }

  Future<bool> isBiometricsEnabled() async {
    final v = await _storage.read(key: _biometricsKey);
    return v == 'true';
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(key: _biometricsKey, value: enabled.toString());
  }

  String _hash(String pin, String salt) {
    return sha256.convert(utf8.encode(pin + salt)).toString();
  }

  String _generateSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Url.encode(bytes);
  }
}
