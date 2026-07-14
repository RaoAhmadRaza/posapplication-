import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../failures/hr_failure.dart';
import '../repositories/hr_repository.dart';
import '../../data/repositories/hr_repository_impl.dart';

class CreatePayrollRun {
  final HrRepository _repo;
  CreatePayrollRun(this._repo);

  Future<(String?, HrFailure?)> call(Map<String, dynamic> data) =>
      _repo.createPayrollRun(data);
}

final createPayrollRunUseCaseProvider = Provider<CreatePayrollRun>((ref) {
  return CreatePayrollRun(ref.read(hrRepositoryProvider));
});
