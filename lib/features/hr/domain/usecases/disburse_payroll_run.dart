import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../failures/hr_failure.dart';
import '../repositories/hr_repository.dart';
import '../../data/repositories/hr_repository_impl.dart';

class DisbursePayrollRun {
  final HrRepository _repo;
  DisbursePayrollRun(this._repo);

  Future<HrFailure?> call({required String runId, required String payAccount}) {
    return _repo.disbursePayrollRun(runId: runId, payAccount: payAccount);
  }
}

final disbursePayrollRunUseCaseProvider =
    Provider<DisbursePayrollRun>((ref) {
  return DisbursePayrollRun(ref.read(hrRepositoryProvider));
});
