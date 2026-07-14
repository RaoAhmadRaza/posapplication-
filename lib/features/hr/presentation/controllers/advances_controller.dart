import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/salary_advance.dart';
import '../../domain/failures/hr_failure.dart';
import '../../domain/usecases/disburse_salary_advance.dart';
import '../../domain/usecases/load_employee_advances.dart';

final employeeAdvancesProvider = FutureProvider.autoDispose
    .family<List<SalaryAdvance>, String>((ref, employeeId) async {
  final (advances, failure) =
      await ref.read(loadEmployeeAdvancesUseCaseProvider).call(employeeId);
  if (failure != null) throw failure;
  return advances;
});

class AdvanceActions {
  AdvanceActions(this._ref);
  final Ref _ref;

  Future<HrFailure?> disburse(
      Map<String, dynamic> data, String employeeId) async {
    final failure =
        await _ref.read(disburseSalaryAdvanceUseCaseProvider).call(data);
    if (failure != null) return failure;
    _ref.invalidate(employeeAdvancesProvider(employeeId));
    return null;
  }
}

final advanceActionsProvider =
    Provider<AdvanceActions>((ref) => AdvanceActions(ref));
