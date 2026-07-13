import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/repair_job.dart';
import '../failures/repair_failure.dart';
import '../repositories/repair_repository.dart';
import '../../data/repositories/repair_repository_impl.dart';

class LoadRepairJobs {
  final RepairRepository _repo;
  LoadRepairJobs(this._repo);

  Future<(List<RepairJob>, RepairFailure?)> call({
    RepairStatus? status,
    String? technicianId,
  }) {
    return _repo.loadRepairJobs(status: status, technicianId: technicianId);
  }
}

final loadRepairJobsUseCaseProvider = Provider<LoadRepairJobs>((ref) {
  return LoadRepairJobs(ref.read(repairRepositoryProvider));
});
