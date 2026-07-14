import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../failures/hr_failure.dart';
import '../repositories/hr_repository.dart';
import '../../data/repositories/hr_repository_impl.dart';

class CalculatePayroll {
  final HrRepository _repo;
  CalculatePayroll(this._repo);

  Future<HrFailure?> call({
    required String runId,
    Map<String, dynamic> allowances = const {},
    Map<String, dynamic> extraDeductions = const {},
  }) {
    return _repo.calculatePayroll(
      runId: runId,
      allowances: allowances,
      extraDeductions: extraDeductions,
    );
  }
}

final calculatePayrollUseCaseProvider = Provider<CalculatePayroll>((ref) {
  return CalculatePayroll(ref.read(hrRepositoryProvider));
});
