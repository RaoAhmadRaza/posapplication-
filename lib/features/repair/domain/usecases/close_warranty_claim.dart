import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/repair_results.dart';
import '../failures/repair_failure.dart';
import '../repositories/repair_repository.dart';
import '../../data/repositories/repair_repository_impl.dart';

class CloseWarrantyClaim {
  final RepairRepository _repo;
  CloseWarrantyClaim(this._repo);

  Future<(RepairWarrantyCloseResult?, RepairFailure?)> call({
    required String repairId,
    int? warrantyDays,
    String? signatureUrl,
  }) {
    return _repo.closeWarrantyClaim(
        repairId: repairId,
        warrantyDays: warrantyDays,
        signatureUrl: signatureUrl);
  }
}

final closeWarrantyClaimUseCaseProvider = Provider<CloseWarrantyClaim>((ref) {
  return CloseWarrantyClaim(ref.read(repairRepositoryProvider));
});
