import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../failures/hr_failure.dart';
import '../repositories/hr_repository.dart';
import '../../data/repositories/hr_repository_impl.dart';

class CreateEmployee {
  final HrRepository _repo;
  CreateEmployee(this._repo);

  Future<(String?, HrFailure?)> call(Map<String, dynamic> data) =>
      _repo.createEmployee(data);
}

final createEmployeeUseCaseProvider = Provider<CreateEmployee>((ref) {
  return CreateEmployee(ref.read(hrRepositoryProvider));
});
