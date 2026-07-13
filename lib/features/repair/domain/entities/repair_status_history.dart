import 'repair_job.dart';

class RepairStatusHistory {
  final String id;
  final String repairId;
  final RepairStatus? oldStatus;
  final RepairStatus newStatus;
  final String changedBy;
  final DateTime changedAt;
  final String? notes;

  const RepairStatusHistory({
    required this.id,
    required this.repairId,
    this.oldStatus,
    required this.newStatus,
    required this.changedBy,
    required this.changedAt,
    this.notes,
  });
}
