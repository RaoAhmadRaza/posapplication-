import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/audit_service.dart';
import '../../../../core/supabase.dart';
import '../../domain/entities/device.dart';
import '../../domain/usecases/approve_device.dart';
import '../../domain/usecases/load_devices.dart';
import '../../domain/usecases/revoke_device.dart';

final devicesProvider =
    NotifierProvider<DevicesController, AsyncValue<List<Device>>>(
  DevicesController.new,
);

class DevicesController extends Notifier<AsyncValue<List<Device>>> {
  @override
  AsyncValue<List<Device>> build() => const AsyncValue.loading();

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final devices = await ref.read(loadDevicesUseCaseProvider).call();
      state = AsyncValue.data(devices);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> approve(String deviceId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await ref.read(approveDeviceUseCaseProvider).call(deviceId, userId);
      AuditService.instance.log(action: 'DEVICE_APPROVE', entity: 'device', entityId: deviceId);
      await load();
    } catch (_) {}
  }

  Future<void> revoke(String deviceId) async {
    try {
      await ref.read(revokeDeviceUseCaseProvider).call(deviceId);
      AuditService.instance.log(action: 'DEVICE_REVOKE', entity: 'device', entityId: deviceId);
      await load();
    } catch (_) {}
  }
}
