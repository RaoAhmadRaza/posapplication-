import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/device_repository_impl.dart';
import '../repositories/device_repository.dart';

class RevokeDevice {
  final DeviceRepository _repo;
  RevokeDevice(this._repo);

  Future<void> call(String deviceId) async {
    return _repo.revokeDevice(deviceId);
  }
}

final revokeDeviceUseCaseProvider = Provider<RevokeDevice>((ref) {
  return RevokeDevice(ref.read(deviceRepositoryProvider));
});
