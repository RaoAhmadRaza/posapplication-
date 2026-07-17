import '../../domain/entities/staff_entities.dart';

DateTime? _dt(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

int _int(dynamic v) => v == null ? 0 : int.tryParse(v.toString()) ?? 0;

/// Row -> entity mappers for the staff feature (no toJson — writes go through
/// RPC param maps built in the repository impl).
class StaffModels {
  static StaffInvite invite(Map<String, dynamic> r) => StaffInvite(
        id: r['id'] as String,
        fullName: r['full_name'] as String?,
        email: r['email'] as String?,
        roleName: (r['role_name'] ?? '').toString(),
        branchNames: ((r['branch_names'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        effectiveStatus: (r['effective_status'] ?? 'PENDING').toString(),
        expiresAt: _dt(r['expires_at']) ?? DateTime.now(),
        createdAt: _dt(r['created_at']) ?? DateTime.now(),
        redeemedAt: _dt(r['redeemed_at']),
      );

  static CreatedInvite createdInvite(Map<String, dynamic> r) => CreatedInvite(
        inviteId: r['invite_id'] as String,
        token: r['token'] as String,
        qrPayload: (r['qr_payload'] ?? '').toString(),
        expiresAt: _dt(r['expires_at']) ?? DateTime.now(),
      );

  static TenantRole role(Map<String, dynamic> r) => TenantRole(
        id: r['id'] as String,
        name: (r['name'] ?? '').toString(),
        description: r['description'] as String?,
        hierarchyLevel: _int(r['hierarchy_level']),
        isSystemRole: r['is_system_role'] as bool? ?? false,
        permissionCount: _int(r['permission_count']),
        userCount: _int(r['user_count']),
      );

  static TenantUser user(Map<String, dynamic> r) => TenantUser(
        id: r['id'] as String,
        fullName: r['full_name'] as String?,
        email: r['email'] as String?,
        roleId: r['role_id'] as String?,
        roleName: r['role_name'] as String?,
        hierarchyLevel:
            r['hierarchy_level'] == null ? null : _int(r['hierarchy_level']),
        status: (r['status'] ?? 'ACTIVE').toString(),
        lastLoginAt: _dt(r['last_login_at']),
      );

  static PermissionCatalogItem catalogItem(Map<String, dynamic> r) =>
      PermissionCatalogItem(
        module: (r['module'] ?? '').toString(),
        action: (r['action'] ?? '').toString(),
      );

  static BranchOption branch(Map<String, dynamic> r) => BranchOption(
        id: r['id'] as String,
        name: (r['name'] ?? '').toString(),
        isMain: r['is_main'] as bool? ?? false,
      );
}
