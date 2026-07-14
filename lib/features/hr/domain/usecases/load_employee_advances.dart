import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/salary_advance.dart';
import '../failures/hr_failure.dart';
import '../repositories/hr_repository.dart';
import '../../data/repositories/hr_repository_impl.dart';

class LoadEmployeeAdvances {
  final HrRepository _repo;
  LoadEmployeeAdvances(this._repo);

  Future<(List<SalaryAdvance>, HrFailure?)> call(String employeeId) =>
      _repo.loadEmployeeAdvances(employeeId);
}

final loadEmployeeAdvancesUseCaseProvider =
    Provider<LoadEmployeeAdvances>((ref) {
  return LoadEmployeeAdvances(ref.read(hrRepositoryProvider));
});
