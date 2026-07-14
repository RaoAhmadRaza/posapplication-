import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/payroll.dart';
import '../../domain/failures/hr_failure.dart';
import '../../domain/usecases/approve_payroll_run.dart';
import '../../domain/usecases/calculate_payroll.dart';
import '../../domain/usecases/create_payroll_run.dart';
import '../../domain/usecases/disburse_payroll_run.dart';
import '../../domain/usecases/load_payroll_run.dart';
import '../../domain/usecases/load_payroll_runs.dart';

typedef PayrollRunDetail = ({PayrollRun run, List<PayrollItem> items});

final payrollRunsProvider =
    AsyncNotifierProvider<PayrollRunsController, List<PayrollRun>>(
  PayrollRunsController.new,
);

class PayrollRunsController extends AsyncNotifier<List<PayrollRun>> {
  @override
  Future<List<PayrollRun>> build() async {
    final (runs, failure) =
        await ref.read(loadPayrollRunsUseCaseProvider).call();
    if (failure != null) throw failure;
    return runs;
  }

  Future<(String?, HrFailure?)> create(Map<String, dynamic> data) async {
    final (id, failure) =
        await ref.read(createPayrollRunUseCaseProvider).call(data);
    if (failure != null) return (null, failure);
    ref.invalidateSelf();
    return (id, null);
  }
}

final payrollRunDetailProvider = FutureProvider.autoDispose
    .family<PayrollRunDetail, String>((ref, id) async {
  final (run, items, failure) =
      await ref.read(loadPayrollRunUseCaseProvider).call(id);
  if (failure != null) throw failure;
  return (run: run!, items: items);
});

class PayrollActions {
  PayrollActions(this._ref);
  final Ref _ref;

  void _refresh(String runId) {
    _ref.invalidate(payrollRunsProvider);
    _ref.invalidate(payrollRunDetailProvider(runId));
  }

  Future<HrFailure?> calculate(String runId,
      {Map<String, dynamic> allowances = const {},
      Map<String, dynamic> extraDeductions = const {}}) async {
    final failure = await _ref.read(calculatePayrollUseCaseProvider).call(
        runId: runId,
        allowances: allowances,
        extraDeductions: extraDeductions);
    if (failure != null) return failure;
    _refresh(runId);
    return null;
  }

  Future<HrFailure?> approve(String runId) async {
    final failure =
        await _ref.read(approvePayrollRunUseCaseProvider).call(runId);
    if (failure != null) return failure;
    _refresh(runId);
    return null;
  }

  Future<HrFailure?> disburse(String runId, String payAccount) async {
    final failure = await _ref
        .read(disbursePayrollRunUseCaseProvider)
        .call(runId: runId, payAccount: payAccount);
    if (failure != null) return failure;
    _refresh(runId);
    return null;
  }
}

final payrollActionsProvider =
    Provider<PayrollActions>((ref) => PayrollActions(ref));
