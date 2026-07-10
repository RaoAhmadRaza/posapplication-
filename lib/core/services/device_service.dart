import 'dart:convert';
import 'dart:io' show Platform;
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/device_repository_impl.dart';
import '../../features/auth/domain/repositories/device_repository.dart';
import '../supabase.dart';

const _storage = FlutterSecureStorage();
const _deviceUuidKey = 'device_uuid';

class DeviceService {
  DeviceService({DeviceRepository? repo})
      : _repo = repo ?? DeviceRepositoryImpl(AuthRemoteDataSource(supabase));

  static final instance = DeviceService();

  final DeviceRepository _repo;

  Future<void> registerDevice({
    required String userId,
    required String tenantId,
  }) async {
    final uuid = await _getOrCreateUuid();
    final deviceInfo = await _collectDeviceInfo();
    final fingerprint = '${deviceInfo.model}|${deviceInfo.osInfo}|$uuid';
    final fingerprintHash = sha256.convert(utf8.encode(fingerprint)).toString();

    final failure = await _repo.registerDevice(
      tenantId: tenantId,
      userId: userId,
      deviceName: deviceInfo.name,
      deviceModel: deviceInfo.model,
      osInfo: deviceInfo.osInfo,
      fingerprintHash: fingerprintHash,
    );
    if (failure != null) {
      debugPrint('[DeviceService] register failed: ${failure.message}');
    }
  }

  Future<String> _getOrCreateUuid() async {
    var uuid = await _storage.read(key: _deviceUuidKey);
    if (uuid == null || uuid.isEmpty) {
      uuid = _generateUuid();
      await _storage.write(key: _deviceUuidKey, value: uuid);
    }
    return uuid;
  }

  Future<_DeviceInfo> _collectDeviceInfo() async {
    final plugin = DeviceInfoPlugin();
    try {
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        return _DeviceInfo(
          name: info.name,
          model: info.model,
          osInfo: '${info.systemName} ${info.systemVersion}',
        );
      }
      if (Platform.isMacOS) {
        final info = await plugin.macOsInfo;
        return _DeviceInfo(
          name: info.computerName,
          model: info.model,
          osInfo: 'macOS ${info.osRelease}',
        );
      }
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return _DeviceInfo(
          name: info.model,
          model: info.model,
          osInfo: 'Android ${info.version.release}',
        );
      }
      if (Platform.isWindows) {
        final info = await plugin.windowsInfo;
        return _DeviceInfo(
          name: info.computerName,
          model: 'Windows',
          osInfo: 'Windows ${info.releaseId}',
        );
      }
      return _DeviceInfo(name: 'Unknown', model: 'Unknown', osInfo: 'Unknown');
    } catch (_) {
      return _DeviceInfo(name: 'Unknown', model: 'Unknown', osInfo: 'Unknown');
    }
  }

  String _generateUuid() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final random = '$now${identityHashCode(this)}';
    return sha256.convert(utf8.encode(random)).toString().substring(0, 32);
  }
}

class _DeviceInfo {
  final String name;
  final String model;
  final String osInfo;
  const _DeviceInfo({
    required this.name,
    required this.model,
    required this.osInfo,
  });
}
