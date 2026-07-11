import '../../domain/entities/dashboard_summary.dart';
import '../failures/dashboard_failure.dart';

abstract class DashboardRepository {
  Future<(DashboardSummary, DashboardFailure?)> loadSummary({
    String? branchId,
    String? from,
    String? to,
  });
}
