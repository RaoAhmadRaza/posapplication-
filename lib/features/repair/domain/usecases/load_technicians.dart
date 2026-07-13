import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/repair_results.dart';
import '../failures/repair_failure.dart';
import '../repositories/repair_repository.dart';
import '../../data/repositories/repair_repository_impl.dart';

class LoadTechnicians {
  final RepairRepository _repo;
  LoadTechnicians(this._repo);

  Future<(List<Technician>, RepairFailure?)> call() {
    return _repo.loadTechnicians();
  }
}

final loadTechniciansUseCaseProvider = Provider<LoadTechnicians>((ref) {
  return LoadTechnicians(ref.read(repairRepositoryProvider));
});
