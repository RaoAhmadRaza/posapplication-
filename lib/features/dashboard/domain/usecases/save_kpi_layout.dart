import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../domain/entities/kpi_pref.dart';
import '../../domain/failures/dashboard_failure.dart';
import '../../domain/repositories/dashboard_repository.dart';

class SaveKpiLayout {
  final DashboardRepository _repo;
  SaveKpiLayout(this._repo);

  Future<DashboardFailure?> call(List<KpiPref> layout) =>
      _repo.saveKpiLayout(layout);
}

final saveKpiLayoutUseCaseProvider = Provider<SaveKpiLayout>((ref) {
  return SaveKpiLayout(ref.read(dashboardRepositoryProvider));
});
