enum RepairStatus {
  received,
  diagnosed,
  awaitingApproval,
  inRepair,
  qc,
  ready,
  delivered,
  warrantyClaim,
  cancelled,
}

enum RepairPriority { low, normal, high, urgent }

class RepairJob {
  final String id;
  final String tenantId;
  final String branchId;
  final String customerId;
  final String jobNumber;
  final String deviceType;
  final String? deviceBrand;
  final String? deviceModel;
  final String? serialNo;
  final String? imei;
  final String reportedIssue;
  final String? diagnosis;
  final String? technicianId;
  final RepairStatus status;
  final RepairPriority priority;
  final double? estimatedCost;
  final double? finalCost;
  final bool? customerApproved;
  final String? invoiceId;
  final DateTime? warrantyExpiresAt;
  final DateTime receivedAt;
  final DateTime? deliveredAt;
  final String? customerSignatureUrl;
  final String? notes;
  final DateTime createdAt;

  /// Display-only, populated by the embedded `customers(name)` join on load.
  final String? customerName;

  const RepairJob({
    required this.id,
    required this.tenantId,
    required this.branchId,
    required this.customerId,
    required this.jobNumber,
    required this.deviceType,
    this.deviceBrand,
    this.deviceModel,
    this.serialNo,
    this.imei,
    required this.reportedIssue,
    this.diagnosis,
    this.technicianId,
    required this.status,
    required this.priority,
    this.estimatedCost,
    this.finalCost,
    this.customerApproved,
    this.invoiceId,
    this.warrantyExpiresAt,
    required this.receivedAt,
    this.deliveredAt,
    this.customerSignatureUrl,
    this.notes,
    required this.createdAt,
    this.customerName,
  });
}
