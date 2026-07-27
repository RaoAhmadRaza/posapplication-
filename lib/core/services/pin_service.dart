import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/pin_repository_impl.dart';
import '../../features/auth/domain/repositories/pin_repository.dart';
import '../supabase.dart';

// macOS: use the legacy keychain, not the data-protection keychain, so writes
// work under the app sandbox without a keychain-access-groups entitlement (that
// entitlement needs a real signing cert — ad-hoc local builds reject it). This
// is what fixes the -34018 "required entitlement isn't present" failures.
// Keep this identical across all secure-storage sites or data splits keychains.
const _storage = FlutterSecureStorage(
  mOptions: MacOsOptions(usesDataProtectionKeychain: false),
);
const _pinHashBase = 'pin_hash';
const _pinSaltBase = 'pin_salt';
const _biometricsBase = 'biometrics_enabled';

class PinService {
  PinService({PinRepository? repo})
      : _repo = repo ?? PinRepositoryImpl(AuthRemoteDataSource(supabase));

  static final instance = PinService();

  final PinRepository _repo;

  String _k(String base) {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return '${base}_no_session';
    return '${base}_$uid';
  }

  // Set once this process has confirmed the global keys are gone. The migration
  // moves process-wide (non-uid) keys to uid-scoped ones and deletes the
  // originals, so once it has run there is nothing left to migrate for any user
  // — re-reading three secure-storage keys on every hasPin/verifyPin/
  // isBiometricsEnabled call is pure cost. Each read is an Android Keystore
  // round-trip, measured at up to ~1.1s on a loaded low-end device.
  bool _migrationChecked = false;

  Future<void> _maybeMigrateGlobalKeys() async {
    if (_migrationChecked) return;

    final uid = supabase.auth.currentUser?.id;
    // Concurrent, not sequential: three independent reads that used to cost
    // three serialised Keystore round-trips before the first frame.
    final [oldHash, oldSalt, oldBio] = await Future.wait([
      _storage.read(key: _pinHashBase),
      _storage.read(key: _pinSaltBase),
      _storage.read(key: _biometricsBase),
    ]);

    if (oldHash == null && oldSalt == null && oldBio == null) {
      _migrationChecked = true;
      return;
    }

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

    _migrationChecked = true;
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
      final failure = await _repo.updatePinHash(userId, hash);
      if (failure != null) {
        debugPrint('[PinService] setPin sync failed: ${failure.message}');
      }
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
      final failure = await _repo.updatePinHash(uid, null);
      if (failure != null) {
        debugPrint('[PinService] clearPin sync failed: ${failure.message}');
      }
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
    final (hash, failure) = await _repo.getServerPinHash(uid);
    if (failure != null) {
      debugPrint('[PinService] getServerPinHash failed: ${failure.message}');
      return null;
    }
    return hash;
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
