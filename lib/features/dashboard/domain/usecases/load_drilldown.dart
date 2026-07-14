import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../domain/entities/drilldown.dart';
import '../../domain/failures/dashboard_failure.dart';
import '../../domain/repositories/dashboard_repository.dart';

class LoadDrilldown {
  final DashboardRepository _repo;
  LoadDrilldown(this._repo);

  Future<(List<DrilldownRow>, DashboardFailure?)> call(DrilldownArgs args) =>
      _repo.loadDrilldown(args);
}

final loadDrilldownUseCaseProvider = Provider<LoadDrilldown>((ref) {
  return LoadDrilldown(ref.read(dashboardRepositoryProvider));
});
