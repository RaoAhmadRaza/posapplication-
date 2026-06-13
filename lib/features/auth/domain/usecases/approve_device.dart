import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/device_repository_impl.dart';
import '../repositories/device_repository.dart';

class ApproveDevice {
  final DeviceRepository _repo;
  ApproveDevice(this._repo);

  Future<void> call(String deviceId, String authorizedBy) async {
    return _repo.approveDevice(deviceId, authorizedBy);
  }
}

final approveDeviceUseCaseProvider = Provider<ApproveDevice>((ref) {
  return ApproveDevice(ref.read(deviceRepositoryProvider));
});
