import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../failures/hr_failure.dart';
import '../repositories/hr_repository.dart';
import '../../data/repositories/hr_repository_impl.dart';

class UpdateEmployee {
  final HrRepository _repo;
  UpdateEmployee(this._repo);

  Future<HrFailure?> call(Map<String, dynamic> data) =>
      _repo.updateEmployee(data);
}

final updateEmployeeUseCaseProvider = Provider<UpdateEmployee>((ref) {
  return UpdateEmployee(ref.read(hrRepositoryProvider));
});
