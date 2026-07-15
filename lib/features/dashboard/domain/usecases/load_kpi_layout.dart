import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../domain/entities/kpi_pref.dart';
import '../../domain/failures/dashboard_failure.dart';
import '../../domain/repositories/dashboard_repository.dart';

class LoadKpiLayout {
  final DashboardRepository _repo;
  LoadKpiLayout(this._repo);

  Future<(List<KpiPref>?, DashboardFailure?)> call() => _repo.loadKpiLayout();
}

final loadKpiLayoutUseCaseProvider = Provider<LoadKpiLayout>((ref) {
  return LoadKpiLayout(ref.read(dashboardRepositoryProvider));
});
