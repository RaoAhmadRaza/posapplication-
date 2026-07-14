import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../failures/hr_failure.dart';
import '../repositories/hr_repository.dart';
import '../../data/repositories/hr_repository_impl.dart';

class ApprovePayrollRun {
  final HrRepository _repo;
  ApprovePayrollRun(this._repo);

  Future<HrFailure?> call(String runId) => _repo.approvePayrollRun(runId);
}

final approvePayrollRunUseCaseProvider = Provider<ApprovePayrollRun>((ref) {
  return ApprovePayrollRun(ref.read(hrRepositoryProvider));
});
