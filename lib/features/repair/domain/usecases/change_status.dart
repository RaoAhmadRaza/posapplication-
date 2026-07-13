import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/repair_job.dart';
import '../failures/repair_failure.dart';
import '../repositories/repair_repository.dart';
import '../../data/repositories/repair_repository_impl.dart';

class ChangeStatus {
  final RepairRepository _repo;
  ChangeStatus(this._repo);

  Future<RepairFailure?> call({
    required String repairId,
    required RepairStatus newStatus,
    String? notes,
  }) {
    return _repo.changeStatus(
        repairId: repairId, newStatus: newStatus, notes: notes);
  }
}

final changeStatusUseCaseProvider = Provider<ChangeStatus>((ref) {
  return ChangeStatus(ref.read(repairRepositoryProvider));
});
