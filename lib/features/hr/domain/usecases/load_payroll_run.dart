import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/payroll.dart';
import '../failures/hr_failure.dart';
import '../repositories/hr_repository.dart';
import '../../data/repositories/hr_repository_impl.dart';

class LoadPayrollRun {
  final HrRepository _repo;
  LoadPayrollRun(this._repo);

  Future<(PayrollRun?, List<PayrollItem>, HrFailure?)> call(String id) =>
      _repo.loadPayrollRun(id);
}

final loadPayrollRunUseCaseProvider = Provider<LoadPayrollRun>((ref) {
  return LoadPayrollRun(ref.read(hrRepositoryProvider));
});
