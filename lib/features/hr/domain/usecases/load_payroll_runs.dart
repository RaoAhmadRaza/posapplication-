import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/payroll.dart';
import '../failures/hr_failure.dart';
import '../repositories/hr_repository.dart';
import '../../data/repositories/hr_repository_impl.dart';

class LoadPayrollRuns {
  final HrRepository _repo;
  LoadPayrollRuns(this._repo);

  Future<(List<PayrollRun>, HrFailure?)> call() => _repo.loadPayrollRuns();
}

final loadPayrollRunsUseCaseProvider = Provider<LoadPayrollRuns>((ref) {
  return LoadPayrollRuns(ref.read(hrRepositoryProvider));
});
