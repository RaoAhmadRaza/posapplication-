// Staff-onboarding domain entities (invites, roles, users, permission catalog).

class StaffInvite {
  const StaffInvite({
    required this.id,
    required this.fullName,
    required this.email,
    required this.roleName,
    required this.branchNames,
    required this.effectiveStatus,
    required this.expiresAt,
    required this.createdAt,
    required this.redeemedAt,
  });

  final String id;
  final String? fullName;
  final String? email;
  final String roleName;
  final List<String> branchNames;

  /// Server-computed: PENDING | AWAITING_CONFIRMATION | REDEEMED | EXPIRED | REVOKED.
  final String effectiveStatus;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime? redeemedAt;

  bool get isPending => effectiveStatus == 'PENDING';
  bool get isAwaitingConfirmation => effectiveStatus == 'AWAITING_CONFIRMATION';
}

/// Returned once by create/regenerate — the raw token is shown a single time.
class CreatedInvite {
  const CreatedInvite({
    required this.inviteId,
    required this.token,
    required this.qrPayload,
    required this.expiresAt,
  });

  final String inviteId;
  final String token;
  final String qrPayload;
  final DateTime expiresAt;
}

class TenantRole {
  const TenantRole({
    required this.id,
    required this.name,
    required this.description,
    required this.hierarchyLevel,
    required this.isSystemRole,
    required this.permissionCount,
    required this.userCount,
  });

  final String id;
  final String name;
  final String? description;
  final int hierarchyLevel;
  final bool isSystemRole;
  final int permissionCount;
  final int userCount;
}

class TenantUser {
  const TenantUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.roleId,
    required this.roleName,
    required this.hierarchyLevel,
    required this.status,
    required this.lastLoginAt,
  });

  final String id;
  final String? fullName;
  final String? email;
  final String? roleId;
  final String? roleName;
  final int? hierarchyLevel;
  final String status;
  final DateTime? lastLoginAt;
}

class PermissionCatalogItem {
  const PermissionCatalogItem({required this.module, required this.action});
  final String module;
  final String action;
  String get key => '$module:$action';
}

class BranchOption {
  const BranchOption({required this.id, required this.name, required this.isMain});
  final String id;
  final String name;
  final bool isMain;
}

/// Result of the anon pre-auth validate_staff_invite call (the invitee side).
class InviteValidation {
  const InviteValidation({
    required this.valid,
    this.businessName,
    this.roleName,
    this.fullName,
    this.email,
    this.emailLocked = false,
    this.reason,
  });

  final bool valid;
  final String? businessName;
  final String? roleName;
  final String? fullName;
  final String? email;
  final bool emailLocked;

  /// When invalid: INVALID | EXPIRED | REVOKED | ALREADY_USED.
  final String? reason;

  String get reasonMessage => switch (reason) {
        'EXPIRED' => 'This invite has expired. Ask your admin for a new one.',
        'REVOKED' => 'This invite was revoked. Ask your admin for a new one.',
        'ALREADY_USED' => 'This invite has already been used.',
        _ => 'This invite code is not valid.',
      };
}
