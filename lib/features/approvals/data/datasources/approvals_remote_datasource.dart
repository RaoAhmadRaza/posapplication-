import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase.dart';

final approvalsRemoteDataSourceProvider =
    Provider<ApprovalsRemoteDataSource>((ref) {
  return ApprovalsRemoteDataSource(supabase);
});

/// The ONLY place the Supabase client is touched for the approvals feature.
class ApprovalsRemoteDataSource {
  final SupabaseClient _client;

  ApprovalsRemoteDataSource(this._client);

  static const _requestCols = 'id, tenant_id, workflow_id, entity_type,'
      ' entity_id, requestor_id, status, current_level, amount, reason,'
      ' expires_at, escalated_at, completed_at, created_at,'
      ' approval_workflows(workflow_type, name),'
      ' requestor:users!approval_requests_requestor_id_fkey(full_name)';

  static const _workflowCols = 'id, tenant_id, workflow_type, name,'
      ' description, threshold_amount, levels_json, escalation_ttl_hours,'
      ' is_active';

  static const _actionCols = 'id, request_id, actor_id, action, level,'
      ' comments, acted_at,'
      ' actor:users!approval_actions_actor_id_fkey(full_name)';

  /// Open requests (PENDING + ESCALATED) for the tenant, oldest first (by age).
  Future<List<Map<String, dynamic>>> loadOpenRequests() async {
    return _client
        .from('approval_requests')
        .select(_requestCols)
        .inFilter('status', ['PENDING', 'ESCALATED']).order('created_at');
  }

  /// Completed requests (APPROVED/REJECTED/EXPIRED/CANCELLED), newest first.
  Future<List<Map<String, dynamic>>> loadHistory() async {
    return _client
        .from('approval_requests')
        .select(_requestCols)
        .inFilter('status',
            ['APPROVED', 'REJECTED', 'EXPIRED', 'CANCELLED']).order(
            'created_at',
            ascending: false);
  }

  Future<Map<String, dynamic>> loadRequest(String id) async {
    return _client
        .from('approval_requests')
        .select(_requestCols)
        .eq('id', id)
        .single();
  }

  Future<Map<String, dynamic>> loadWorkflow(String id) async {
    return _client
        .from('approval_workflows')
        .select(_workflowCols)
        .eq('id', id)
        .single();
  }

  Future<List<Map<String, dynamic>>> loadActions(String requestId) async {
    return _client
        .from('approval_actions')
        .select(_actionCols)
        .eq('request_id', requestId)
        .order('acted_at');
  }

  /// APPROVE / REJECT at the current level. Returns the RPC's single Map.
  Future<Map<String, dynamic>> actOnApproval({
    required String requestId,
    required String action,
    String? comments,
  }) async {
    final result = await _client.rpc('act_on_approval', params: {
      'p_request_id': requestId,
      'p_action': action,
      'p_comments': comments,
    });
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelRequest({
    required String requestId,
    String? reason,
  }) async {
    final result = await _client.rpc('cancel_approval_request', params: {
      'p_request_id': requestId,
      'p_reason': reason,
    });
    return result as Map<String, dynamic>;
  }

  /// Configured workflows (not soft-deleted), optionally one type.
  Future<List<Map<String, dynamic>>> loadWorkflows({String? type}) async {
    var q = _client
        .from('approval_workflows')
        .select(_workflowCols)
        .isFilter('deleted_at', null);
    if (type != null) q = q.eq('workflow_type', type);
    return q.order('workflow_type').order('name');
  }

  /// Tenant role names for the levels editor (RLS scopes to tenant).
  Future<List<Map<String, dynamic>>> loadRoles() async {
    return _client.from('roles').select('id, name').order('name');
  }

  /// Insert (id == null) or update a workflow config. Returns {workflow_id}.
  Future<Map<String, dynamic>> upsertWorkflow(Map<String, dynamic> data) async {
    final result = await _client.rpc('upsert_approval_workflow', params: {
      'p_id': data['p_id'],
      'p_type': data['p_type'],
      'p_name': data['p_name'],
      'p_description': data['p_description'],
      'p_threshold_amount': data['p_threshold_amount'],
      'p_levels_json': data['p_levels_json'],
      'p_escalation_ttl_hours': data['p_escalation_ttl_hours'],
      'p_is_active': data['p_is_active'],
    });
    return result as Map<String, dynamic>;
  }

  /// Manual raise. Returns {required, request_id?, status?, existing?}.
  Future<Map<String, dynamic>> requestApproval({
    required String type,
    required String entityType,
    required String entityId,
    double? amount,
    String? reason,
    String? correlationId,
  }) async {
    final result = await _client.rpc('request_approval', params: {
      'p_type': type,
      'p_entity_type': entityType,
      'p_entity_id': entityId,
      'p_amount': amount,
      'p_reason': reason,
      'p_correlation': correlationId,
    });
    return result as Map<String, dynamic>;
  }
}
