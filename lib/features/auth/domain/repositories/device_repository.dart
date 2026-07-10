import '../../../../core/error/auth_failure.dart';
import '../../domain/entities/device.dart';

abstract class DeviceRepository {
  Future<List<Device>> loadDevices();
  Future<void> approveDevice(String deviceId, String authorizedBy);
  Future<void> revokeDevice(String deviceId);

  /// null = registered; non-null = mapped failure (caller logs it).
  Future<AuthFailure?> registerDevice({
    required String tenantId,
    required String userId,
    required String deviceName,
    required String deviceModel,
    required String osInfo,
    required String fingerprintHash,
  });
}
