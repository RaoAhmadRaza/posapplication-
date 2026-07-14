import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../failures/hr_failure.dart';
import '../repositories/hr_repository.dart';
import '../../data/repositories/hr_repository_impl.dart';

class DisburseSalaryAdvance {
  final HrRepository _repo;
  DisburseSalaryAdvance(this._repo);

  Future<HrFailure?> call(Map<String, dynamic> data) =>
      _repo.disburseSalaryAdvance(data);
}

final disburseSalaryAdvanceUseCaseProvider =
    Provider<DisburseSalaryAdvance>((ref) {
  return DisburseSalaryAdvance(ref.read(hrRepositoryProvider));
});
