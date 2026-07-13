import '../../domain/entities/repair_status_history.dart';
import 'repair_job_model.dart';

class RepairStatusHistoryModel {
  static RepairStatusHistory fromJson(Map<String, dynamic> json) {
    return RepairStatusHistory(
      id: json['id'] as String,
      repairId: json['repair_id'] as String,
      oldStatus: json['old_status'] == null
          ? null
          : RepairJobModel.parseStatus(json['old_status'] as String?),
      newStatus: RepairJobModel.parseStatus(json['new_status'] as String?),
      changedBy: json['changed_by'] as String,
      changedAt: DateTime.parse(json['changed_at'] as String),
      notes: json['notes'] as String?,
    );
  }
}
