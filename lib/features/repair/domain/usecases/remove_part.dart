import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../failures/repair_failure.dart';
import '../repositories/repair_repository.dart';
import '../../data/repositories/repair_repository_impl.dart';

class RemovePart {
  final RepairRepository _repo;
  RemovePart(this._repo);

  Future<RepairFailure?> call(String repairPartId) {
    return _repo.removePart(repairPartId);
  }
}

final removePartUseCaseProvider = Provider<RemovePart>((ref) {
  return RemovePart(ref.read(repairRepositoryProvider));
});
