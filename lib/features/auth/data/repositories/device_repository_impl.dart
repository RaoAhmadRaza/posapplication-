import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/auth_failure.dart';
import '../../../../core/error/supabase_error_mapper.dart';
import '../datasources/auth_remote_datasource.dart';
import '../../domain/entities/device.dart';
import '../../domain/repositories/device_repository.dart';

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceRepositoryImpl(ref.read(authRemoteDataSourceProvider));
});

class DeviceRepositoryImpl implements DeviceRepository {
  final AuthRemoteDataSource _ds;

  DeviceRepositoryImpl(this._ds);

  @override
  Future<List<Device>> loadDevices() async {
    final rows = await _ds.loadDevices();
    return rows.map((r) => Device.fromJson(r)).toList();
  }

  @override
  Future<void> approveDevice(String deviceId, String authorizedBy) async {
    await _ds.approveDevice(deviceId, authorizedBy);
  }

  @override
  Future<void> revokeDevice(String deviceId) async {
    await _ds.revokeDevice(deviceId);
  }

  @override
  Future<AuthFailure?> registerDevice({
    required String tenantId,
    required String userId,
    required String deviceName,
    required String deviceModel,
    required String osInfo,
    required String fingerprintHash,
  }) async {
    try {
      await _ds.registerDevice(
        tenantId: tenantId,
        userId: userId,
        deviceName: deviceName,
        deviceModel: deviceModel,
        osInfo: osInfo,
        fingerprintHash: fingerprintHash,
      );
      return null;
    } catch (e) {
      debugPrint('[DeviceRepository] register failed: $e');
      return mapSupabaseFailure(e);
    }
  }
}
