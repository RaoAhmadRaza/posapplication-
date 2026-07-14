import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/employee.dart';
import '../failures/hr_failure.dart';
import '../repositories/hr_repository.dart';
import '../../data/repositories/hr_repository_impl.dart';

class LoadEmployee {
  final HrRepository _repo;
  LoadEmployee(this._repo);

  Future<(Employee?, HrFailure?)> call(String id) => _repo.loadEmployee(id);
}

final loadEmployeeUseCaseProvider = Provider<LoadEmployee>((ref) {
  return LoadEmployee(ref.read(hrRepositoryProvider));
});
