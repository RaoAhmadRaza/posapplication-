import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/employee.dart';
import '../failures/hr_failure.dart';
import '../repositories/hr_repository.dart';
import '../../data/repositories/hr_repository_impl.dart';

class TerminateEmployee {
  final HrRepository _repo;
  TerminateEmployee(this._repo);

  Future<HrFailure?> call({
    required String employeeId,
    required EmployeeStatus status,
    DateTime? terminationDate,
    String? notes,
  }) {
    return _repo.terminateEmployee(
      employeeId: employeeId,
      status: status,
      terminationDate: terminationDate,
      notes: notes,
    );
  }
}

final terminateEmployeeUseCaseProvider = Provider<TerminateEmployee>((ref) {
  return TerminateEmployee(ref.read(hrRepositoryProvider));
});
