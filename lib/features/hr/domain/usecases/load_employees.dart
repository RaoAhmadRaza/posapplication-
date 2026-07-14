import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/employee.dart';
import '../failures/hr_failure.dart';
import '../repositories/hr_repository.dart';
import '../../data/repositories/hr_repository_impl.dart';

class LoadEmployees {
  final HrRepository _repo;
  LoadEmployees(this._repo);

  Future<(List<Employee>, HrFailure?)> call({
    String? branchId,
    EmployeeStatus? status,
    String? department,
    String? query,
  }) {
    return _repo.loadEmployees(
      branchId: branchId,
      status: status,
      department: department,
      query: query,
    );
  }
}

final loadEmployeesUseCaseProvider = Provider<LoadEmployees>((ref) {
  return LoadEmployees(ref.read(hrRepositoryProvider));
});
