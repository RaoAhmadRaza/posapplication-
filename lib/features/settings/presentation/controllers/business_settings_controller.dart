import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/tenant_settings.dart';
import '../../domain/failures/settings_failure.dart';
import '../../domain/usecases/settings_usecases.dart';

final businessSettingsProvider =
    AsyncNotifierProvider<BusinessSettingsController, TenantSettings>(
  BusinessSettingsController.new,
);

class BusinessSettingsController extends AsyncNotifier<TenantSettings> {
  @override
  Future<TenantSettings> build() async {
    final (settings, failure) =
        await ref.read(loadTenantSettingsUseCaseProvider)();
    if (failure != null) throw failure;
    return settings!;
  }

  /// Patches settings_json (shallow merge server-side). Returns a failure or null.
  Future<SettingsFailure?> save(Map<String, dynamic> patch) async {
    final (json, failure) =
        await ref.read(updateTenantSettingsUseCaseProvider)(patch);
    if (failure != null) return failure;
    final current = state.value;
    state = AsyncData(TenantSettings(
      tenantName: current?.tenantName ?? '',
      json: json ?? const {},
    ));
    return null;
  }
}
