import 'dart:typed_data';

import '../entities/repair_job.dart';
import '../entities/repair_part.dart';
import '../entities/repair_status_history.dart';
import '../entities/repair_results.dart';
import '../failures/repair_failure.dart';

abstract class RepairRepository {
  Future<(List<RepairJob>, RepairFailure?)> loadRepairJobs({
    RepairStatus? status,
    String? technicianId,
  });

  /// Delivered + cancelled jobs, for the history view.
  Future<(List<RepairJob>, RepairFailure?)> loadClosedRepairJobs();

  Future<(RepairJob?, List<RepairPart>, List<RepairStatusHistory>,
      RepairFailure?)> loadRepairJob(String id);

  Future<(RepairCreateResult?, RepairFailure?)> createRepairJob(
      Map<String, dynamic> data);

  Future<RepairFailure?> assignTechnician(String repairId, String technicianId);

  Future<RepairFailure?> setDiagnosis({
    required String repairId,
    required String diagnosis,
    double? estimatedCost,
    bool? customerApproved,
  });

  Future<RepairFailure?> changeStatus({
    required String repairId,
    required RepairStatus newStatus,
    String? notes,
  });

  /// Bulk status change; each job validated independently, failures collected.
  Future<(RepairBulkStatusResult?, RepairFailure?)> bulkChangeStatus({
    required List<String> repairIds,
    required RepairStatus newStatus,
    String? notes,
  });

  Future<(RepairPartResult?, RepairFailure?)> addPart({
    required String repairId,
    required String productId,
    String? variantId,
    required double qty,
    String? notes,
  });

  Future<RepairFailure?> removePart(String repairPartId);

  Future<(RepairCloseResult?, RepairFailure?)> closeJob({
    required String repairId,
    required double labourPrice,
    required double labourTaxPct,
    required Map<String, double> partsMarkup,
    required double paidAmount,
    int? warrantyDays,
    String? signatureUrl,
  });

  Future<(List<Technician>, RepairFailure?)> loadTechnicians();

  /// Uploads a signature PNG for a repair; returns the storage path.
  Future<(String?, RepairFailure?)> uploadSignature(
      String repairId, Uint8List bytes);

  /// Fresh short-lived signed URL for a stored signature path.
  Future<(String?, RepairFailure?)> signatureSignedUrl(String path);
}
