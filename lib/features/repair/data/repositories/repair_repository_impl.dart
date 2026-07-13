import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/repair_job.dart';
import '../../domain/entities/repair_part.dart';
import '../../domain/entities/repair_status_history.dart';
import '../../domain/entities/repair_results.dart';
import '../../domain/failures/repair_failure.dart';
import '../../domain/repositories/repair_repository.dart';
import '../datasources/repair_remote_datasource.dart';
import '../models/repair_job_model.dart';
import '../models/repair_part_model.dart';
import '../models/repair_status_history_model.dart';
import '../models/repair_result_models.dart';

final repairRepositoryProvider = Provider<RepairRepository>((ref) {
  return RepairRepositoryImpl(ref.read(repairRemoteDataSourceProvider));
});

class RepairRepositoryImpl implements RepairRepository {
  final RepairRemoteDataSource _ds;

  RepairRepositoryImpl(this._ds);

  RepairFailure _mapError(Object e) {
    if (e is PostgrestException) {
      final msg = e.message.toLowerCase();
      final code = e.code;
      if (msg.contains('err_permission_denied') || code == '42501') {
        return RepairPermissionDeniedFailure();
      }
      if (msg.contains('err_use_close_to_deliver')) {
        return RepairUseCloseToDeliverFailure();
      }
      if (msg.contains('err_invalid_transition')) {
        return RepairInvalidTransitionFailure();
      }
      if (msg.contains('err_job_not_ready')) {
        return RepairJobNotReadyFailure();
      }
      if (msg.contains('err_job_closed')) return RepairJobClosedFailure();
      if (msg.contains('_not_found') ||
          code == 'PGRST116' ||
          code == 'P0002') {
        return RepairNotFoundFailure();
      }
    }
    if (e is AuthException) return RepairPermissionDeniedFailure();
    if (e is SocketException || e is TimeoutException) {
      return RepairUnknownFailure(
          'Network error. Please check your connection.');
    }
    return RepairUnknownFailure(e.toString());
  }

  @override
  Future<(List<RepairJob>, RepairFailure?)> loadRepairJobs({
    RepairStatus? status,
    String? technicianId,
  }) async {
    try {
      final rows = await _ds.loadRepairJobs(
        status: status == null ? null : RepairJobModel.statusToDb(status),
        technicianId: technicianId,
      );
      return (rows.map(RepairJobModel.fromJson).toList(), null);
    } catch (e) {
      return (<RepairJob>[], _mapError(e));
    }
  }

  @override
  Future<(List<RepairJob>, RepairFailure?)> loadClosedRepairJobs() async {
    try {
      final rows = await _ds.loadClosedRepairJobs();
      return (rows.map(RepairJobModel.fromJson).toList(), null);
    } catch (e) {
      return (<RepairJob>[], _mapError(e));
    }
  }

  @override
  Future<(RepairJob?, List<RepairPart>, List<RepairStatusHistory>,
      RepairFailure?)> loadRepairJob(String id) async {
    try {
      final jobRow = await _ds.loadRepairJob(id);
      final partRows = await _ds.loadRepairParts(id);
      final historyRows = await _ds.loadStatusHistory(id);
      return (
        RepairJobModel.fromJson(jobRow),
        partRows.map(RepairPartModel.fromJson).toList(),
        historyRows.map(RepairStatusHistoryModel.fromJson).toList(),
        null,
      );
    } catch (e) {
      return (null, <RepairPart>[], <RepairStatusHistory>[], _mapError(e));
    }
  }

  @override
  Future<(RepairCreateResult?, RepairFailure?)> createRepairJob(
      Map<String, dynamic> data) async {
    try {
      final row = await _ds.createRepairJob(data);
      return (RepairCreateResultModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<RepairFailure?> assignTechnician(
      String repairId, String technicianId) async {
    try {
      await _ds.assignTechnician(repairId, technicianId);
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<RepairFailure?> setDiagnosis({
    required String repairId,
    required String diagnosis,
    double? estimatedCost,
    bool? customerApproved,
  }) async {
    try {
      await _ds.setDiagnosis(
        repairId: repairId,
        diagnosis: diagnosis,
        estimatedCost: estimatedCost,
        customerApproved: customerApproved,
      );
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<RepairFailure?> changeStatus({
    required String repairId,
    required RepairStatus newStatus,
    String? notes,
  }) async {
    try {
      await _ds.changeStatus(
        repairId: repairId,
        newStatus: RepairJobModel.statusToDb(newStatus),
        notes: notes,
      );
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<(RepairPartResult?, RepairFailure?)> addPart({
    required String repairId,
    required String productId,
    String? variantId,
    required double qty,
    String? notes,
  }) async {
    try {
      final row = await _ds.addPart(
        repairId: repairId,
        productId: productId,
        variantId: variantId,
        qty: qty,
        notes: notes,
      );
      return (RepairPartResultModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<RepairFailure?> removePart(String repairPartId) async {
    try {
      await _ds.removePart(repairPartId);
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<(RepairCloseResult?, RepairFailure?)> closeJob({
    required String repairId,
    required double labourPrice,
    required double labourTaxPct,
    required Map<String, double> partsMarkup,
    required double paidAmount,
    int? warrantyDays,
    String? signatureUrl,
  }) async {
    try {
      final row = await _ds.closeJob(
        repairId: repairId,
        labourPrice: labourPrice,
        labourTaxPct: labourTaxPct,
        partsMarkup: partsMarkup,
        paidAmount: paidAmount,
        warrantyDays: warrantyDays,
        signatureUrl: signatureUrl,
      );
      return (RepairCloseResultModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(List<Technician>, RepairFailure?)> loadTechnicians() async {
    try {
      final rows = await _ds.loadTechnicians();
      final techs = rows
          .map((r) => Technician(
                id: r['id'] as String,
                name: (r['full_name'] as String?)?.trim().isNotEmpty == true
                    ? r['full_name'] as String
                    : 'Unnamed user',
              ))
          .toList();
      return (techs, null);
    } catch (e) {
      return (<Technician>[], _mapError(e));
    }
  }

  @override
  Future<(String?, RepairFailure?)> uploadSignature(
      String repairId, Uint8List bytes) async {
    try {
      return (await _ds.uploadSignature(repairId, bytes), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(String?, RepairFailure?)> signatureSignedUrl(String path) async {
    try {
      return (await _ds.signatureSignedUrl(path), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }
}
