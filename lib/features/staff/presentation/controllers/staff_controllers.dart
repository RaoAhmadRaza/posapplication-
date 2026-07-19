import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/staff_repository_impl.dart';
import '../../domain/entities/staff_entities.dart';
import '../../domain/failures/staff_failure.dart';
import '../../domain/repositories/staff_repository.dart';

// ---- lists ----
class InvitesController extends AsyncNotifier<List<StaffInvite>> {
  @override
  Future<List<StaffInvite>> build() async {
    final (rows, failure) = await ref.read(staffRepositoryProvider).listInvites();
    if (failure != null) throw failure;
    return rows;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final (rows, f) = await ref.read(staffRepositoryProvider).listInvites();
      if (f != null) throw f;
      return rows;
    });
  }
}

final invitesControllerProvider =
    AsyncNotifierProvider<InvitesController, List<StaffInvite>>(
  InvitesController.new,
);

class RolesController extends AsyncNotifier<List<TenantRole>> {
  @override
  Future<List<TenantRole>> build() async {
    final (rows, failure) = await ref.read(staffRepositoryProvider).listRoles();
    if (failure != null) throw failure;
    return rows;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final (rows, f) = await ref.read(staffRepositoryProvider).listRoles();
      if (f != null) throw f;
      return rows;
    });
  }
}

final rolesControllerProvider =
    AsyncNotifierProvider<RolesController, List<TenantRole>>(
  RolesController.new,
);

class TenantUsersController extends AsyncNotifier<List<TenantUser>> {
  @override
  Future<List<TenantUser>> build() async {
    final (rows, failure) = await ref.read(staffRepositoryProvider).listUsers();
    if (failure != null) throw failure;
    return rows;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final (rows, f) = await ref.read(staffRepositoryProvider).listUsers();
      if (f != null) throw f;
      return rows;
    });
  }
}

final tenantUsersControllerProvider =
    AsyncNotifierProvider<TenantUsersController, List<TenantUser>>(
  TenantUsersController.new,
);

// ---- form data ----
final permissionCatalogProvider =
    FutureProvider.autoDispose<List<PermissionCatalogItem>>((ref) async {
  final (rows, f) =
      await ref.read(staffRepositoryProvider).listPermissionCatalog();
  if (f != null) throw f;
  return rows;
});

final branchOptionsProvider =
    FutureProvider.autoDispose<List<BranchOption>>((ref) async {
  final (rows, f) = await ref.read(staffRepositoryProvider).listBranches();
  if (f != null) throw f;
  return rows;
});

// ---- mutations (return Failure? and invalidate the affected lists) ----
class StaffActions {
  StaffActions(this._ref);
  final Ref _ref;

  StaffRepository get _repo => _ref.read(staffRepositoryProvider);

  Future<(CreatedInvite?, StaffFailure?)> createInvite({
    required String roleId,
    required List<String> branchIds,
    String? fullName,
    String? email,
    String? employeeId,
    int expiresInHours = 72,
  }) async {
    final res = await _repo.createInvite(
      roleId: roleId,
      branchIds: branchIds,
      fullName: fullName,
      email: email,
      employeeId: employeeId,
      expiresInHours: expiresInHours,
    );
    if (res.$2 == null) _ref.invalidate(invitesControllerProvider);
    return res;
  }

  Future<(CreatedInvite?, StaffFailure?)> regenerateInvite(String id) async {
    final res = await _repo.regenerateInvite(id);
    if (res.$2 == null) _ref.invalidate(invitesControllerProvider);
    return res;
  }

  Future<StaffFailure?> revokeInvite(String id) async {
    final f = await _repo.revokeInvite(id);
    if (f == null) _ref.invalidate(invitesControllerProvider);
    return f;
  }

  Future<StaffFailure?> releaseAbandoned(String id) async {
    final f = await _repo.releaseAbandoned(id);
    if (f == null) _ref.invalidate(invitesControllerProvider);
    return f;
  }

  Future<(String?, StaffFailure?)> createRole({
    required String name,
    String? description,
    required int hierarchyLevel,
    required List<PermissionGrant> permissions,
  }) async {
    final res = await _repo.createRole(
      name: name,
      description: description,
      hierarchyLevel: hierarchyLevel,
      permissions: permissions,
    );
    if (res.$2 == null) _ref.invalidate(rolesControllerProvider);
    return res;
  }

  Future<StaffFailure?> updateUserRole(String userId, String roleId) async {
    final f = await _repo.updateUserRole(userId, roleId);
    if (f == null) {
      _ref.invalidate(tenantUsersControllerProvider);
      _ref.invalidate(rolesControllerProvider);
    }
    return f;
  }

  Future<StaffFailure?> updateRolePermissions(
      String roleId, List<PermissionGrant> permissions) async {
    final f = await _repo.updateRolePermissions(roleId, permissions);
    if (f == null) _ref.invalidate(rolesControllerProvider);
    return f;
  }
}

final staffActionsProvider = Provider<StaffActions>((ref) => StaffActions(ref));

// Current granted permissions for a role, keyed by roleId, to prefill the edit
// form. autoDispose so each edit session re-fetches fresh.
final rolePermissionsProvider = FutureProvider.autoDispose
    .family<List<PermissionGrant>, String>((ref, roleId) async {
  final (grants, failure) =
      await ref.read(staffRepositoryProvider).loadRolePermissions(roleId);
  if (failure != null) throw failure;
  return grants;
});
