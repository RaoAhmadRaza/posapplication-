import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/failures/dashboard_failure.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../domain/repositories/dashboard_repository.dart';

class LoadDashboardSummary {
  final DashboardRepository _repo;
  LoadDashboardSummary(this._repo);

  Future<(DashboardSummary, DashboardFailure?)> call({
    String? branchId,
    String? from,
    String? to,
  }) async {
    return _repo.loadSummary(branchId: branchId, from: from, to: to);
  }
}

final loadDashboardSummaryUseCaseProvider = Provider<LoadDashboardSummary>((ref) {
  return LoadDashboardSummary(ref.read(dashboardRepositoryProvider));
});
