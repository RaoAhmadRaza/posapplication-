import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/device_repository_impl.dart';
import '../entities/device.dart';
import '../repositories/device_repository.dart';

class LoadDevices {
  final DeviceRepository _repo;
  LoadDevices(this._repo);

  Future<List<Device>> call() async {
    return _repo.loadDevices();
  }
}

final loadDevicesUseCaseProvider = Provider<LoadDevices>((ref) {
  return LoadDevices(ref.read(deviceRepositoryProvider));
});
