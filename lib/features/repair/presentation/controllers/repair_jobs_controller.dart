import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/repair_job.dart';
import '../../domain/entities/repair_results.dart';
import '../../domain/failures/repair_failure.dart';
import '../../domain/usecases/load_repair_jobs.dart';
import '../../domain/usecases/create_repair_job.dart';
import '../../domain/usecases/assign_technician.dart';
import '../../domain/usecases/set_diagnosis.dart';
import '../../domain/usecases/change_status.dart';
import '../../domain/usecases/bulk_change_status.dart';
import '../../domain/usecases/add_part.dart';
import '../../domain/usecases/remove_part.dart';
import '../../domain/usecases/close_job.dart';
import 'repair_detail_provider.dart';

final repairJobsProvider =
    AsyncNotifierProvider<RepairJobsController, List<RepairJob>>(
  RepairJobsController.new,
);

class RepairJobsController extends AsyncNotifier<List<RepairJob>> {
  RepairStatus? _status;
  String? _technicianId;

  RepairStatus? get statusFilter => _status;
  String? get technicianFilter => _technicianId;

  @override
  Future<List<RepairJob>> build() async {
    final (jobs, failure) = await ref
        .read(loadRepairJobsUseCaseProvider)
        .call(status: _status, technicianId: _technicianId);
    if (failure != null) throw failure;
    return jobs;
  }

  Future<void> setFilters({
    RepairStatus? status,
    String? technicianId,
    bool clearTechnician = false,
  }) async {
    _status = status;
    if (clearTechnician) _technicianId = null;
    if (technicianId != null) _technicianId = technicianId;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final (jobs, failure) = await ref
          .read(loadRepairJobsUseCaseProvider)
          .call(status: _status, technicianId: _technicianId);
      if (failure != null) throw failure;
      return jobs;
    });
  }

  void refresh() => ref.invalidateSelf();

  void _invalidateDetail(String id) => ref.invalidate(repairJobDetailProvider(id));

  Future<(RepairCreateResult?, RepairFailure?)> create(
      Map<String, dynamic> data) async {
    final (result, failure) =
        await ref.read(createRepairJobUseCaseProvider).call(data);
    if (failure != null) return (null, failure);
    ref.invalidateSelf();
    return (result, null);
  }

  Future<RepairFailure?> assignTechnician(
      String repairId, String technicianId) async {
    final failure = await ref
        .read(assignTechnicianUseCaseProvider)
        .call(repairId, technicianId);
    if (failure != null) return failure;
    ref.invalidateSelf();
    _invalidateDetail(repairId);
    return null;
  }

  Future<RepairFailure?> setDiagnosis({
    required String repairId,
    required String diagnosis,
    double? estimatedCost,
    bool? customerApproved,
  }) async {
    final failure = await ref.read(setDiagnosisUseCaseProvider).call(
          repairId: repairId,
          diagnosis: diagnosis,
          estimatedCost: estimatedCost,
          customerApproved: customerApproved,
        );
    if (failure != null) return failure;
    ref.invalidateSelf();
    _invalidateDetail(repairId);
    return null;
  }

  Future<RepairFailure?> changeStatus({
    required String repairId,
    required RepairStatus newStatus,
    String? notes,
  }) async {
    final failure = await ref.read(changeStatusUseCaseProvider).call(
        repairId: repairId, newStatus: newStatus, notes: notes);
    if (failure != null) return failure;
    ref.invalidateSelf();
    _invalidateDetail(repairId);
    return null;
  }

  /// Bulk status change across many jobs; returns the per-job outcome so the UI
  /// can report succeeded count + list failures. Refreshes the board after.
  Future<(RepairBulkStatusResult?, RepairFailure?)> bulkChangeStatus({
    required List<String> repairIds,
    required RepairStatus newStatus,
    String? notes,
  }) async {
    final (result, failure) = await ref.read(bulkChangeStatusUseCaseProvider).call(
        repairIds: repairIds, newStatus: newStatus, notes: notes);
    if (failure != null) return (null, failure);
    ref.invalidateSelf();
    for (final id in repairIds) {
      _invalidateDetail(id);
    }
    return (result, null);
  }

  Future<RepairFailure?> addPart({
    required String repairId,
    required String productId,
    String? variantId,
    required double qty,
    String? notes,
  }) async {
    final (_, failure) = await ref.read(addPartUseCaseProvider).call(
          repairId: repairId,
          productId: productId,
          variantId: variantId,
          qty: qty,
          notes: notes,
        );
    if (failure != null) return failure;
    _invalidateDetail(repairId);
    return null;
  }

  Future<RepairFailure?> removePart(String repairId, String repairPartId) async {
    final failure =
        await ref.read(removePartUseCaseProvider).call(repairPartId);
    if (failure != null) return failure;
    _invalidateDetail(repairId);
    return null;
  }

  Future<(RepairCloseResult?, RepairFailure?)> closeJob({
    required String repairId,
    required double labourPrice,
    required double labourTaxPct,
    required Map<String, double> partsMarkup,
    required double paidAmount,
    int? warrantyDays,
    String? signatureUrl,
  }) async {
    final (result, failure) = await ref.read(closeJobUseCaseProvider).call(
          repairId: repairId,
          labourPrice: labourPrice,
          labourTaxPct: labourTaxPct,
          partsMarkup: partsMarkup,
          paidAmount: paidAmount,
          warrantyDays: warrantyDays,
          signatureUrl: signatureUrl,
        );
    if (failure != null) return (null, failure);
    ref.invalidateSelf();
    _invalidateDetail(repairId);
    return (result, null);
  }
}
