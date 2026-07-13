import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/repair_results.dart';
import '../failures/repair_failure.dart';
import '../repositories/repair_repository.dart';
import '../../data/repositories/repair_repository_impl.dart';

class CloseJob {
  final RepairRepository _repo;
  CloseJob(this._repo);

  Future<(RepairCloseResult?, RepairFailure?)> call({
    required String repairId,
    required double labourPrice,
    required double labourTaxPct,
    required Map<String, double> partsMarkup,
    required double paidAmount,
    int? warrantyDays,
    String? signatureUrl,
  }) {
    return _repo.closeJob(
      repairId: repairId,
      labourPrice: labourPrice,
      labourTaxPct: labourTaxPct,
      partsMarkup: partsMarkup,
      paidAmount: paidAmount,
      warrantyDays: warrantyDays,
      signatureUrl: signatureUrl,
    );
  }
}

final closeJobUseCaseProvider = Provider<CloseJob>((ref) {
  return CloseJob(ref.read(repairRepositoryProvider));
});
