import '../../domain/entities/approval.dart';

class ApprovalTypeMapper {
  static String typeToDb(ApprovalWorkflowType t) => switch (t) {
        ApprovalWorkflowType.purchaseOrder => 'PURCHASE_ORDER',
        ApprovalWorkflowType.stockAdjustment => 'STOCK_ADJUSTMENT',
        ApprovalWorkflowType.discountOverride => 'DISCOUNT_OVERRIDE',
        ApprovalWorkflowType.payrollDisbursement => 'PAYROLL_DISBURSEMENT',
        ApprovalWorkflowType.creditLimitChange => 'CREDIT_LIMIT_CHANGE',
        ApprovalWorkflowType.priceChange => 'PRICE_CHANGE',
        ApprovalWorkflowType.refund => 'REFUND',
        ApprovalWorkflowType.expense => 'EXPENSE',
      };

  static ApprovalWorkflowType? parseType(String? t) =>
      switch ((t ?? '').toUpperCase()) {
        'PURCHASE_ORDER' => ApprovalWorkflowType.purchaseOrder,
        'STOCK_ADJUSTMENT' => ApprovalWorkflowType.stockAdjustment,
        'DISCOUNT_OVERRIDE' => ApprovalWorkflowType.discountOverride,
        'PAYROLL_DISBURSEMENT' => ApprovalWorkflowType.payrollDisbursement,
        'CREDIT_LIMIT_CHANGE' => ApprovalWorkflowType.creditLimitChange,
        'PRICE_CHANGE' => ApprovalWorkflowType.priceChange,
        'REFUND' => ApprovalWorkflowType.refund,
        'EXPENSE' => ApprovalWorkflowType.expense,
        _ => null,
      };

  static String statusToDb(ApprovalStatus s) => switch (s) {
        ApprovalStatus.pending => 'PENDING',
        ApprovalStatus.approved => 'APPROVED',
        ApprovalStatus.rejected => 'REJECTED',
        ApprovalStatus.escalated => 'ESCALATED',
        ApprovalStatus.expired => 'EXPIRED',
        ApprovalStatus.cancelled => 'CANCELLED',
      };

  static ApprovalStatus parseStatus(String? s) =>
      switch ((s ?? 'PENDING').toUpperCase()) {
        'PENDING' => ApprovalStatus.pending,
        'APPROVED' => ApprovalStatus.approved,
        'REJECTED' => ApprovalStatus.rejected,
        'ESCALATED' => ApprovalStatus.escalated,
        'EXPIRED' => ApprovalStatus.expired,
        'CANCELLED' => ApprovalStatus.cancelled,
        _ => ApprovalStatus.pending,
      };
}

class ApprovalWorkflowModel {
  static ApprovalWorkflow fromJson(Map<String, dynamic> json) {
    return ApprovalWorkflow(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      workflowType: ApprovalTypeMapper.parseType(json['workflow_type'] as String?) ??
          ApprovalWorkflowType.expense,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      thresholdAmount: json['threshold_amount'] == null
          ? null
          : double.tryParse(json['threshold_amount'].toString()),
      levels: _parseLevels(json['levels_json']),
      escalationTtlHours:
          int.tryParse('${json['escalation_ttl_hours'] ?? 24}') ?? 24,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  static List<ApprovalLevel> _parseLevels(dynamic raw) {
    if (raw is! List) return const [];
    final out = <ApprovalLevel>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final level = int.tryParse('${e['level']}');
      final role = e['required_role'] as String?;
      if (level == null || role == null) continue;
      out.add(ApprovalLevel(
        level: level,
        requiredRole: role,
        minApprovers: int.tryParse('${e['min_approvers'] ?? 1}') ?? 1,
      ));
    }
    out.sort((a, b) => a.level.compareTo(b.level));
    return out;
  }
}

class ApprovalRequestModel {
  static ApprovalRequest fromJson(Map<String, dynamic> json) {
    final workflow = json['approval_workflows'] as Map<String, dynamic>?;
    final requestor = json['requestor'] as Map<String, dynamic>?;
    return ApprovalRequest(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      workflowId: json['workflow_id'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      requestorId: json['requestor_id'] as String,
      status: ApprovalTypeMapper.parseStatus(json['status'] as String?),
      currentLevel: int.tryParse('${json['current_level'] ?? 1}') ?? 1,
      amount: json['amount'] == null
          ? null
          : double.tryParse(json['amount'].toString()),
      reason: json['reason'] as String?,
      expiresAt: _dt(json['expires_at']),
      escalatedAt: _dt(json['escalated_at']),
      completedAt: _dt(json['completed_at']),
      createdAt: _dt(json['created_at']) ?? DateTime.now(),
      requestorName: requestor?['full_name'] as String?,
      workflowType:
          ApprovalTypeMapper.parseType(workflow?['workflow_type'] as String?),
      workflowName: workflow?['name'] as String?,
    );
  }
}

class ApprovalActionModel {
  static ApprovalAction fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>?;
    return ApprovalAction(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      actorId: json['actor_id'] as String,
      action: json['action'] as String? ?? '',
      level: int.tryParse('${json['level'] ?? 1}') ?? 1,
      comments: json['comments'] as String?,
      actedAt: _dt(json['acted_at']) ?? DateTime.now(),
      actorName: actor?['full_name'] as String?,
    );
  }
}

DateTime? _dt(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString())?.toLocal();
}
