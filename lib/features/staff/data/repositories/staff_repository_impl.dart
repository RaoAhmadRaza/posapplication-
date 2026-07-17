import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/staff_entities.dart';
import '../../domain/failures/staff_failure.dart';
import '../../domain/repositories/staff_repository.dart';
import '../datasources/staff_remote_datasource.dart';
import '../models/staff_models.dart';

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  return StaffRepositoryImpl(ref.read(staffRemoteDataSourceProvider));
});

class StaffRepositoryImpl implements StaffRepository {
  StaffRepositoryImpl(this._ds);
  final StaffRemoteDataSource _ds;

  StaffFailure _mapError(Object e) {
    if (e is PostgrestException) {
      final msg = e.message.toLowerCase();
      final code = e.code;
      if (msg.contains('err_cannot_grant_unheld_permission')) {
        return StaffCannotGrantFailure();
      }
      if (msg.contains('err_hierarchy_violation') ||
          msg.contains('err_invalid_hierarchy')) {
        return StaffHierarchyFailure();
      }
      if (msg.contains('err_last_admin_cannot_be_demoted')) {
        return StaffLastAdminFailure();
      }
      if (msg.contains('err_only_admin_can_create_admin') ||
          msg.contains('err_reserved_role_name') ||
          msg.contains('err_forbidden') ||
          code == '42501') {
        return StaffPermissionDeniedFailure();
      }
      if (msg.contains('err_invite_not_found') ||
          msg.contains('err_role_not_in_tenant') ||
          msg.contains('err_user_not_in_tenant') ||
          msg.contains('err_invite_not_redeemed') ||
          code == 'PGRST116' ||
          code == 'P0002') {
        return StaffNotFoundFailure();
      }
      if (msg.contains('err_')) {
        return StaffValidationFailure(_humanize(e.message));
      }
    }
    if (e is AuthException) return StaffPermissionDeniedFailure();
    if (e is SocketException || e is TimeoutException) {
      return StaffUnknownFailure('Network error. Please check your connection.');
    }
    return StaffUnknownFailure(e.toString());
  }

  String _humanize(String raw) {
    final head = raw.split('\n').first.replaceFirst(RegExp(r'^ERR_'), '');
    return head.replaceAll('_', ' ').toLowerCase();
  }

  @override
  Future<(List<StaffInvite>, StaffFailure?)> listInvites() async {
    try {
      final rows = await _ds.listInvites();
      return (rows.map(StaffModels.invite).toList(), null);
    } catch (e) {
      return (<StaffInvite>[], _mapError(e));
    }
  }

  @override
  Future<(CreatedInvite?, StaffFailure?)> createInvite({
    required String roleId,
    required List<String> branchIds,
    String? fullName,
    String? email,
    String? employeeId,
    int expiresInHours = 72,
  }) async {
    try {
      final row = await _ds.createInvite(
        roleId: roleId,
        branchIds: branchIds,
        fullName: fullName,
        email: email,
        employeeId: employeeId,
        expiresInHours: expiresInHours,
      );
      return (StaffModels.createdInvite(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(CreatedInvite?, StaffFailure?)> regenerateInvite(
      String inviteId) async {
    try {
      final row = await _ds.regenerateInvite(inviteId);
      return (StaffModels.createdInvite(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<StaffFailure?> revokeInvite(String inviteId) async {
    try {
      await _ds.revokeInvite(inviteId);
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<StaffFailure?> releaseAbandoned(String inviteId) async {
    try {
      await _ds.releaseAbandoned(inviteId);
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<(List<TenantRole>, StaffFailure?)> listRoles() async {
    try {
      final rows = await _ds.listRoles();
      return (rows.map(StaffModels.role).toList(), null);
    } catch (e) {
      return (<TenantRole>[], _mapError(e));
    }
  }

  @override
  Future<(List<PermissionCatalogItem>, StaffFailure?)>
      listPermissionCatalog() async {
    try {
      final rows = await _ds.listPermissionCatalog();
      return (rows.map(StaffModels.catalogItem).toList(), null);
    } catch (e) {
      return (<PermissionCatalogItem>[], _mapError(e));
    }
  }

  @override
  Future<(String?, StaffFailure?)> createRole({
    required String name,
    String? description,
    required int hierarchyLevel,
    required List<PermissionGrant> permissions,
  }) async {
    try {
      final id = await _ds.createRole(
        name: name,
        description: description,
        hierarchyLevel: hierarchyLevel,
        permissions: permissions.map((p) => p.toJson()).toList(),
      );
      return (id, null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<StaffFailure?> updateRolePermissions(
      String roleId, List<PermissionGrant> permissions) async {
    try {
      await _ds.updateRolePermissions(
          roleId, permissions.map((p) => p.toJson()).toList());
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<(List<TenantUser>, StaffFailure?)> listUsers() async {
    try {
      final rows = await _ds.listUsers();
      return (rows.map(StaffModels.user).toList(), null);
    } catch (e) {
      return (<TenantUser>[], _mapError(e));
    }
  }

  @override
  Future<StaffFailure?> updateUserRole(String userId, String roleId) async {
    try {
      await _ds.updateUserRole(userId, roleId);
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<(List<BranchOption>, StaffFailure?)> listBranches() async {
    try {
      final rows = await _ds.listBranches();
      return (rows.map(StaffModels.branch).toList(), null);
    } catch (e) {
      return (<BranchOption>[], _mapError(e));
    }
  }

  @override
  Future<(InviteValidation?, StaffFailure?)> validateInvite(String token) async {
    try {
      final v = await _ds.validateInvite(token);
      return (
        InviteValidation(
          valid: v['valid'] == true,
          businessName: v['business_name'] as String?,
          roleName: v['role_name'] as String?,
          fullName: v['full_name'] as String?,
          email: v['email'] as String?,
          emailLocked: v['email_locked'] as bool? ?? false,
          reason: v['reason'] as String?,
        ),
        null
      );
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(String?, StaffFailure?)> redeemInvite({
    required String email,
    required String password,
    required String token,
    String? fullName,
  }) async {
    try {
      final pending = await _ds.redeemInvite(
          email: email, password: password, token: token, fullName: fullName);
      return (pending, null);
    } catch (e) {
      // 7.6: the trigger raise surfaces as a generic 500 — re-validate to find
      // the real reason instead of parsing the auth error text.
      try {
        final v = await _ds.validateInvite(token);
        if (v['valid'] != true) {
          return (
            null,
            StaffValidationFailure(InviteValidation(
                    valid: false, reason: v['reason'] as String?)
                .reasonMessage)
          );
        }
      } catch (_) {}
      if (e is AuthException) {
        return (
          null,
          StaffValidationFailure(
              'Could not create your account. The email may already be in use, or the password is too weak.')
        );
      }
      return (null, _mapError(e));
    }
  }
}
