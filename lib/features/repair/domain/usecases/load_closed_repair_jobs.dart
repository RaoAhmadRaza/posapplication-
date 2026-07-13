import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/repair_job.dart';
import '../failures/repair_failure.dart';
import '../repositories/repair_repository.dart';
import '../../data/repositories/repair_repository_impl.dart';

class LoadClosedRepairJobs {
  final RepairRepository _repo;
  LoadClosedRepairJobs(this._repo);

  Future<(List<RepairJob>, RepairFailure?)> call() {
    return _repo.loadClosedRepairJobs();
  }
}

final loadClosedRepairJobsUseCaseProvider =
    Provider<LoadClosedRepairJobs>((ref) {
  return LoadClosedRepairJobs(ref.read(repairRepositoryProvider));
});
