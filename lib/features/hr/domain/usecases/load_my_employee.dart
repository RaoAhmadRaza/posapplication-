import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/employee.dart';
import '../failures/hr_failure.dart';
import '../repositories/hr_repository.dart';
import '../../data/repositories/hr_repository_impl.dart';

class LoadMyEmployee {
  final HrRepository _repo;
  LoadMyEmployee(this._repo);

  Future<(Employee?, HrFailure?)> call() => _repo.loadMyEmployee();
}

final loadMyEmployeeUseCaseProvider = Provider<LoadMyEmployee>((ref) {
  return LoadMyEmployee(ref.read(hrRepositoryProvider));
});
