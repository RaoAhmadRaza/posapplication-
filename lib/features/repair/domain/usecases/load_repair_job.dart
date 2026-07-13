import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/repair_job.dart';
import '../entities/repair_part.dart';
import '../entities/repair_status_history.dart';
import '../failures/repair_failure.dart';
import '../repositories/repair_repository.dart';
import '../../data/repositories/repair_repository_impl.dart';

class LoadRepairJob {
  final RepairRepository _repo;
  LoadRepairJob(this._repo);

  Future<(RepairJob?, List<RepairPart>, List<RepairStatusHistory>,
      RepairFailure?)> call(String id) {
    return _repo.loadRepairJob(id);
  }
}

final loadRepairJobUseCaseProvider = Provider<LoadRepairJob>((ref) {
  return LoadRepairJob(ref.read(repairRepositoryProvider));
});
