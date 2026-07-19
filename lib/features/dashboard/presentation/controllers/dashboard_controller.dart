import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/usecases/load_dashboard_summary.dart';

final dashboardProvider = AsyncNotifierProvider<DashboardController, DashboardSummary>(
  DashboardController.new,
);

class DashboardController extends AsyncNotifier<DashboardSummary> {
  @override
  Future<DashboardSummary> build() async {
    final branch = ref.read(currentBranchProvider);
    final (summary, failure) = await ref
        .read(loadDashboardSummaryUseCaseProvider)
        .call(branchId: branch?.id);
    if (failure != null) throw failure;
    return summary;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
