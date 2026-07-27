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
    // Note: a sign-out/sign-in cannot leave the previous user's matrix behind —
    // SessionScope throws away the whole container on a user change, so this
    // controller is rebuilt from scratch and starts here, on loading.
    return const AsyncValue.loading();
  }

  /// Load [roleId]'s matrix unless it is already loaded. Level-triggered, so a
  /// screen that mounts *after* the profile resolved still gets a matrix — the
  /// edge-triggered `ref.listen` in workspace-init alone can miss the emission
  /// and leave this stuck on loading forever.
  void ensureLoadedFor(String roleId) {
    // load() sets _roleId synchronously, so an in-flight load for the same role
    // is a no-op here; a failed one retries.
    if (_roleId == roleId && !state.hasError) return;
    load(roleId);
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
