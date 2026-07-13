import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/repair_results.dart';
import '../failures/repair_failure.dart';
import '../repositories/repair_repository.dart';
import '../../data/repositories/repair_repository_impl.dart';

class LoadRepairLinks {
  final RepairRepository _repo;
  LoadRepairLinks(this._repo);

  Future<(List<RepairLink>, RepairFailure?)> call(
          String repairId, String? originalRepairId) =>
      _repo.loadRepairLinks(repairId, originalRepairId);
}

final loadRepairLinksUseCaseProvider = Provider<LoadRepairLinks>((ref) {
  return LoadRepairLinks(ref.read(repairRepositoryProvider));
});
