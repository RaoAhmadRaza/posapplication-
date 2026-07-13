import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/repair_results.dart';
import '../failures/repair_failure.dart';
import '../repositories/repair_repository.dart';
import '../../data/repositories/repair_repository_impl.dart';

class OpenWarrantyClaim {
  final RepairRepository _repo;
  OpenWarrantyClaim(this._repo);

  Future<(RepairWarrantyOpenResult?, RepairFailure?)> call({
    required String originalRepairId,
    required String reportedIssue,
  }) {
    return _repo.openWarrantyClaim(
        originalRepairId: originalRepairId, reportedIssue: reportedIssue);
  }
}

final openWarrantyClaimUseCaseProvider = Provider<OpenWarrantyClaim>((ref) {
  return OpenWarrantyClaim(ref.read(repairRepositoryProvider));
});
