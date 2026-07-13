import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../failures/repair_failure.dart';
import '../repositories/repair_repository.dart';
import '../../data/repositories/repair_repository_impl.dart';

class SetDiagnosis {
  final RepairRepository _repo;
  SetDiagnosis(this._repo);

  Future<RepairFailure?> call({
    required String repairId,
    required String diagnosis,
    double? estimatedCost,
    bool? customerApproved,
  }) {
    return _repo.setDiagnosis(
      repairId: repairId,
      diagnosis: diagnosis,
      estimatedCost: estimatedCost,
      customerApproved: customerApproved,
    );
  }
}

final setDiagnosisUseCaseProvider = Provider<SetDiagnosis>((ref) {
  return SetDiagnosis(ref.read(repairRepositoryProvider));
});
