import '../../domain/entities/device.dart';

abstract class DeviceRepository {
  Future<List<Device>> loadDevices();
  Future<void> approveDevice(String deviceId, String authorizedBy);
  Future<void> revokeDevice(String deviceId);
}
