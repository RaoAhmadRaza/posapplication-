import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/realtime/subscribe_reload.dart';
import '../../domain/usecases/load_permissions.dart';

final permissionMatrixProvider =
    NotifierProvider<PermissionController, AsyncValue<Set<String>>>(
  PermissionController.new,
);

final permissionsReadyProvider = Provider<bool>((ref) {
  final state = ref.watch(permissionMatrixProvider);
  return !state.isLoading && !state.hasError;
});

final canProvider = Provider.family.autoDispose<bool, (String, String)>((ref, key) {
  final state = ref.watch(permissionMatrixProvider);
  final matrix = state.value;
  if (matrix == null) return false;
  final entry = '${key.$1}:${key.$2}';
  return matrix.contains(entry);
});

class PermissionController extends Notifier<AsyncValue<Set<String>>> {
  String? _roleId;

  @override
  AsyncValue<Set<String>> build() {
    // Re-fetch the matrix when this tenant's permissions change, so an admin's
    // grant/revoke reaches an already-logged-in session without a re-login
    // (K.2). RLS scopes the stream to the tenant; reloading own role is cheap
    // and idempotent even when the change was to another role.
    subscribeReload(ref, 'permissions', () {
      final roleId = _roleId;
      if (roleId != null) load(roleId);
    });
    return const AsyncValue.loading();
  }

  Future<void> load(String roleId) async {
    _roleId = roleId;
    state = const AsyncValue.loading();
    final (perms, failure) =
        await ref.read(loadPermissionsUseCaseProvider).call(roleId);
    if (failure != null) {
      state = AsyncValue.error(failure, StackTrace.current);
    } else {
      final matrix = perms
          .where((p) => p.granted)
          .map((p) => p.key)
          .toSet();
      state = AsyncValue.data(matrix);
    }
  }

  bool can(String module, String action) {
    final matrix = state.value;
    if (matrix == null) return false;
    return matrix.contains('$module:$action');
  }
}
