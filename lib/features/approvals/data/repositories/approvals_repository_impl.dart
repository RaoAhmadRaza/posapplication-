import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/approval.dart';
import '../../domain/failures/approval_failure.dart';
import '../../domain/repositories/approvals_repository.dart';
import '../datasources/approvals_remote_datasource.dart';
import '../models/approval_models.dart';

final approvalsRepositoryProvider = Provider<ApprovalsRepository>((ref) {
  return ApprovalsRepositoryImpl(ref.read(approvalsRemoteDataSourceProvider));
});

class ApprovalsRepositoryImpl implements ApprovalsRepository {
  final ApprovalsRemoteDataSource _ds;

  ApprovalsRepositoryImpl(this._ds);

  ApprovalFailure _mapError(Object e) {
    if (e is PostgrestException) {
      final msg = e.message.toLowerCase();
      final code = e.code;
      if (msg.contains('err_role_not_allowed')) {
        return ApprovalRoleNotAllowedFailure();
      }
      if (msg.contains('err_already_acted')) {
        return ApprovalAlreadyActedFailure();
      }
      if (msg.contains('err_not_open')) return ApprovalNotOpenFailure();
      if (msg.contains('err_request_not_found')) {
        return ApprovalRequestNotFoundFailure();
      }
      if (msg.contains('err_workflow_not_found')) {
        return ApprovalWorkflowNotFoundFailure();
      }
      if (msg.contains('err_levels_required') || msg.contains('err_level')) {
        return ApprovalLevelsRequiredFailure();
      }
      if (msg.contains('err_permission_denied') || code == '42501') {
        return ApprovalPermissionDeniedFailure();
      }
      if (code == 'PGRST116' || code == 'P0002') {
        return ApprovalRequestNotFoundFailure();
      }
    }
    if (e is AuthException) return ApprovalPermissionDeniedFailure();
    if (e is SocketException || e is TimeoutException) {
      return ApprovalUnknownFailure(
          'Network error. Please check your connection.');
    }
    return ApprovalUnknownFailure(e.toString());
  }

  @override
  Future<(List<ApprovalRequest>, ApprovalFailure?)> loadOpenRequests() async {
    try {
      final rows = await _ds.loadOpenRequests();
      return (rows.map(ApprovalRequestModel.fromJson).toList(), null);
    } catch (e) {
      return (<ApprovalRequest>[], _mapError(e));
    }
  }

  @override
  Future<(List<ApprovalRequest>, ApprovalFailure?)> loadHistory() async {
    try {
      final rows = await _ds.loadHistory();
      return (rows.map(ApprovalRequestModel.fromJson).toList(), null);
    } catch (e) {
      return (<ApprovalRequest>[], _mapError(e));
    }
  }

  @override
  Future<(ApprovalRequest?, List<ApprovalAction>, ApprovalWorkflow?,
      ApprovalFailure?)> loadDetail(String id) async {
    try {
      final requestRow = await _ds.loadRequest(id);
      final request = ApprovalRequestModel.fromJson(requestRow);
      final actionRows = await _ds.loadActions(id);
      final actions =
          actionRows.map(ApprovalActionModel.fromJson).toList();
      final workflowRow = await _ds.loadWorkflow(request.workflowId);
      final workflow = ApprovalWorkflowModel.fromJson(workflowRow);
      return (request, actions, workflow, null);
    } catch (e) {
      return (null, <ApprovalAction>[], null, _mapError(e));
    }
  }

  @override
  Future<ApprovalFailure?> act({
    required String requestId,
    required String action,
    String? comments,
  }) async {
    try {
      await _ds.actOnApproval(
          requestId: requestId, action: action, comments: comments);
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<ApprovalFailure?> cancel({
    required String requestId,
    String? reason,
  }) async {
    try {
      await _ds.cancelRequest(requestId: requestId, reason: reason);
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<(List<ApprovalWorkflow>, ApprovalFailure?)> loadWorkflows({
    String? type,
  }) async {
    try {
      final rows = await _ds.loadWorkflows(type: type);
      return (rows.map(ApprovalWorkflowModel.fromJson).toList(), null);
    } catch (e) {
      return (<ApprovalWorkflow>[], _mapError(e));
    }
  }

  @override
  Future<(List<String>, ApprovalFailure?)> loadRoleNames() async {
    try {
      final rows = await _ds.loadRoles();
      final names = rows
          .map((r) => r['name'] as String?)
          .whereType<String>()
          .toList();
      return (names, null);
    } catch (e) {
      return (<String>[], _mapError(e));
    }
  }

  @override
  Future<(String?, ApprovalFailure?)> upsertWorkflow({
    String? id,
    required ApprovalWorkflowType type,
    required String name,
    String? description,
    double? thresholdAmount,
    required List<ApprovalLevel> levels,
    int escalationTtlHours = 24,
    bool isActive = true,
  }) async {
    try {
      final levelsJson = [
        for (final l in levels)
          {
            'level': l.level,
            'required_role': l.requiredRole,
            'min_approvers': l.minApprovers,
          },
      ];
      final row = await _ds.upsertWorkflow({
        'p_id': id,
        'p_type': ApprovalTypeMapper.typeToDb(type),
        'p_name': name,
        'p_description': description,
        'p_threshold_amount': thresholdAmount,
        'p_levels_json': levelsJson,
        'p_escalation_ttl_hours': escalationTtlHours,
        'p_is_active': isActive,
      });
      return (row['workflow_id'] as String?, null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(Map<String, dynamic>?, ApprovalFailure?)> requestApproval({
    required String type,
    required String entityType,
    required String entityId,
    double? amount,
    String? reason,
    String? correlationId,
  }) async {
    try {
      final result = await _ds.requestApproval(
        type: type,
        entityType: entityType,
        entityId: entityId,
        amount: amount,
        reason: reason,
        correlationId: correlationId,
      );
      return (result, null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }
}
