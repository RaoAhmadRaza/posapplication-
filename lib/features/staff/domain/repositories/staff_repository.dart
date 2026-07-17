import '../entities/staff_entities.dart';
import '../failures/staff_failure.dart';

/// A single (module, action) grant with an optional branch scope, used when
/// building or editing a role's permission set.
class PermissionGrant {
  const PermissionGrant({
    required this.module,
    required this.action,
    this.branchScope = 'OWN_BRANCH',
  });
  final String module;
  final String action;
  final String branchScope;

  Map<String, dynamic> toJson() =>
      {'module': module, 'action': action, 'branch_scope': branchScope};
}

abstract class StaffRepository {
  // Invites
  Future<(List<StaffInvite>, StaffFailure?)> listInvites();
  Future<(CreatedInvite?, StaffFailure?)> createInvite({
    required String roleId,
    required List<String> branchIds,
    String? fullName,
    String? email,
    String? employeeId,
    int expiresInHours,
  });
  Future<(CreatedInvite?, StaffFailure?)> regenerateInvite(String inviteId);
  Future<StaffFailure?> revokeInvite(String inviteId);
  Future<StaffFailure?> releaseAbandoned(String inviteId);

  // Roles & permissions
  Future<(List<TenantRole>, StaffFailure?)> listRoles();
  Future<(List<PermissionCatalogItem>, StaffFailure?)> listPermissionCatalog();
  Future<(String?, StaffFailure?)> createRole({
    required String name,
    String? description,
    required int hierarchyLevel,
    required List<PermissionGrant> permissions,
  });
  Future<StaffFailure?> updateRolePermissions(
      String roleId, List<PermissionGrant> permissions);

  // Users
  Future<(List<TenantUser>, StaffFailure?)> listUsers();
  Future<StaffFailure?> updateUserRole(String userId, String roleId);

  // Branches (for the invite form)
  Future<(List<BranchOption>, StaffFailure?)> listBranches();

  // Invitee side (pre-auth)
  Future<(InviteValidation?, StaffFailure?)> validateInvite(String token);

  /// Returns the email if confirmation is still pending (no session), else null
  /// (already signed in). A failure carries the real reason (re-validated).
  Future<(String?, StaffFailure?)> redeemInvite({
    required String email,
    required String password,
    required String token,
    String? fullName,
  });
}
