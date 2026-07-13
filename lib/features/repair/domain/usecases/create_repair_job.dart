import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/repair_results.dart';
import '../failures/repair_failure.dart';
import '../repositories/repair_repository.dart';
import '../../data/repositories/repair_repository_impl.dart';

class CreateRepairJob {
  final RepairRepository _repo;
  CreateRepairJob(this._repo);

  Future<(RepairCreateResult?, RepairFailure?)> call(
      Map<String, dynamic> data) {
    return _repo.createRepairJob(data);
  }
}

final createRepairJobUseCaseProvider = Provider<CreateRepairJob>((ref) {
  return CreateRepairJob(ref.read(repairRepositoryProvider));
});
