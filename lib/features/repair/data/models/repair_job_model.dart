import '../../domain/entities/repair_job.dart';

class RepairJobModel {
  static RepairJob fromJson(Map<String, dynamic> json) {
    return RepairJob(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      branchId: json['branch_id'] as String,
      customerId: json['customer_id'] as String,
      jobNumber: json['job_number'] as String,
      deviceType: json['device_type'] as String,
      deviceBrand: json['device_brand'] as String?,
      deviceModel: json['device_model'] as String?,
      serialNo: json['serial_no'] as String?,
      imei: json['imei'] as String?,
      reportedIssue: json['reported_issue'] as String,
      diagnosis: json['diagnosis'] as String?,
      technicianId: json['technician_id'] as String?,
      status: parseStatus(json['status'] as String?),
      priority: parsePriority(json['priority'] as String?),
      estimatedCost: json['estimated_cost'] == null
          ? null
          : double.tryParse(json['estimated_cost'].toString()),
      finalCost: json['final_cost'] == null
          ? null
          : double.tryParse(json['final_cost'].toString()),
      customerApproved: json['customer_approved'] as bool?,
      invoiceId: json['invoice_id'] as String?,
      warrantyExpiresAt: json['warranty_expires_at'] == null
          ? null
          : DateTime.tryParse(json['warranty_expires_at'].toString()),
      receivedAt: DateTime.parse(json['received_at'] as String),
      deliveredAt: json['delivered_at'] == null
          ? null
          : DateTime.tryParse(json['delivered_at'].toString()),
      customerSignatureUrl: json['customer_signature_url'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      customerName: (json['customers'] as Map<String, dynamic>?)?['name']
          as String?,
      originalRepairId: json['original_repair_id'] as String?,
    );
  }

  static String statusToDb(RepairStatus s) => switch (s) {
        RepairStatus.received => 'RECEIVED',
        RepairStatus.diagnosed => 'DIAGNOSED',
        RepairStatus.awaitingApproval => 'AWAITING_APPROVAL',
        RepairStatus.inRepair => 'IN_REPAIR',
        RepairStatus.qc => 'QC',
        RepairStatus.ready => 'READY',
        RepairStatus.delivered => 'DELIVERED',
        RepairStatus.warrantyClaim => 'WARRANTY_CLAIM',
        RepairStatus.cancelled => 'CANCELLED',
      };

  static RepairStatus parseStatus(String? s) {
    return switch ((s ?? 'RECEIVED').toUpperCase()) {
      'RECEIVED' => RepairStatus.received,
      'DIAGNOSED' => RepairStatus.diagnosed,
      'AWAITING_APPROVAL' => RepairStatus.awaitingApproval,
      'IN_REPAIR' => RepairStatus.inRepair,
      'QC' => RepairStatus.qc,
      'READY' => RepairStatus.ready,
      'DELIVERED' => RepairStatus.delivered,
      'WARRANTY_CLAIM' => RepairStatus.warrantyClaim,
      'CANCELLED' => RepairStatus.cancelled,
      _ => RepairStatus.received,
    };
  }

  static String priorityToDb(RepairPriority p) => switch (p) {
        RepairPriority.low => 'LOW',
        RepairPriority.normal => 'NORMAL',
        RepairPriority.high => 'HIGH',
        RepairPriority.urgent => 'URGENT',
      };

  static RepairPriority parsePriority(String? p) {
    return switch ((p ?? 'NORMAL').toUpperCase()) {
      'LOW' => RepairPriority.low,
      'NORMAL' => RepairPriority.normal,
      'HIGH' => RepairPriority.high,
      'URGENT' => RepairPriority.urgent,
      _ => RepairPriority.normal,
    };
  }
}
