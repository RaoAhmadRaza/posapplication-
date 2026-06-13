import 'package:flutter_riverpod/flutter_riverpod.dart';
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
}
