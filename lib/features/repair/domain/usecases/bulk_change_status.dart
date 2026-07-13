import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/repair_job.dart';
import '../entities/repair_results.dart';
import '../failures/repair_failure.dart';
import '../repositories/repair_repository.dart';
import '../../data/repositories/repair_repository_impl.dart';

class BulkChangeStatus {
  final RepairRepository _repo;
  BulkChangeStatus(this._repo);

  Future<(RepairBulkStatusResult?, RepairFailure?)> call({
    required List<String> repairIds,
    required RepairStatus newStatus,
    String? notes,
  }) {
    return _repo.bulkChangeStatus(
        repairIds: repairIds, newStatus: newStatus, notes: notes);
  }
}

final bulkChangeStatusUseCaseProvider = Provider<BulkChangeStatus>((ref) {
  return BulkChangeStatus(ref.read(repairRepositoryProvider));
});
