import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../failures/repair_failure.dart';
import '../repositories/repair_repository.dart';
import '../../data/repositories/repair_repository_impl.dart';

class AssignTechnician {
  final RepairRepository _repo;
  AssignTechnician(this._repo);

  Future<RepairFailure?> call(String repairId, String technicianId) {
    return _repo.assignTechnician(repairId, technicianId);
  }
}

final assignTechnicianUseCaseProvider = Provider<AssignTechnician>((ref) {
  return AssignTechnician(ref.read(repairRepositoryProvider));
});
