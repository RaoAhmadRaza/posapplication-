import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../supabase.dart';

const _storage = FlutterSecureStorage();
const _pinHashBase = 'pin_hash';
const _pinSaltBase = 'pin_salt';
const _biometricsBase = 'biometrics_enabled';

class PinService {
  static const instance = PinService._();
  const PinService._();

  String _k(String base) {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return '${base}_no_session';
    return '${base}_$uid';
  }

  Future<void> _maybeMigrateGlobalKeys() async {
    final uid = supabase.auth.currentUser?.id;
    final oldHash = await _storage.read(key: _pinHashBase);
    final oldSalt = await _storage.read(key: _pinSaltBase);
    final oldBio = await _storage.read(key: _biometricsBase);

    if (oldHash == null && oldSalt == null && oldBio == null) return;

    if (uid != null) {
      if (oldHash != null) {
        await _storage.write(key: _k(_pinHashBase), value: oldHash);
      }
      if (oldSalt != null) {
        await _storage.write(key: _k(_pinSaltBase), value: oldSalt);
      }
      if (oldBio != null) {
        await _storage.write(key: _k(_biometricsBase), value: oldBio);
      }
    }

    await _storage.delete(key: _pinHashBase);
    await _storage.delete(key: _pinSaltBase);
    await _storage.delete(key: _biometricsBase);
  }

  Future<bool> hasPin() async {
    await _maybeMigrateGlobalKeys();
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return false;
    final hash = await _storage.read(key: _k(_pinHashBase));
    return hash != null && hash.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hash(pin, salt);
    await _storage.write(key: _k(_pinSaltBase), value: salt);
    await _storage.write(key: _k(_pinHashBase), value: hash);

    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      try {
        await supabase
            .from('users')
            .update({'pin_hash': hash}).eq('id', userId);
      } catch (_) {}
    }
  }

  Future<bool> verifyPin(String pin) async {
    await _maybeMigrateGlobalKeys();
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return false;
    final hash = await _storage.read(key: _k(_pinHashBase));
    final salt = await _storage.read(key: _k(_pinSaltBase));
    if (hash == null || salt == null) return false;
    return _hash(pin, salt) == hash;
  }

  Future<void> clearPin() async {
    final uid = supabase.auth.currentUser?.id;
    await _storage.delete(key: _k(_pinHashBase));
    await _storage.delete(key: _k(_pinSaltBase));
    await _storage.delete(key: _k(_biometricsBase));

    if (uid != null) {
      try {
        await supabase
            .from('users')
            .update({'pin_hash': null}).eq('id', uid);
      } catch (_) {}
    }
  }

  Future<bool> isBiometricsEnabled() async {
    await _maybeMigrateGlobalKeys();
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return false;
    final v = await _storage.read(key: _k(_biometricsBase));
    return v == 'true';
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(
        key: _k(_biometricsBase), value: enabled.toString());
  }

  Future<String?> getServerPinHash() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final data = await supabase
          .from('users')
          .select('pin_hash')
          .eq('id', uid)
          .single();
      return data['pin_hash'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> reconcilePinFromServer(String serverHash) async {
    if (serverHash.isEmpty) {
      final localHash =
          await _storage.read(key: _k(_pinHashBase));
      if (localHash != null && localHash.isNotEmpty) {
        await _storage.delete(key: _k(_pinHashBase));
        await _storage.delete(key: _k(_pinSaltBase));
      }
      return;
    }

    final localHash = await _storage.read(key: _k(_pinHashBase));
    if (localHash == null || localHash.isEmpty) {
      await _storage.write(key: _k(_pinHashBase), value: serverHash);
    }
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
