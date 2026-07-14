import '../entities/ai_recommendation.dart';
import '../entities/report_schedule.dart';
import '../entities/reporting.dart';
import '../failures/reporting_failure.dart';

abstract class ReportingRepository {
  Future<(List<InventoryValuationRow>, ReportingFailure?)> inventoryValuation();
  Future<(List<ProductPerformanceRow>, ReportingFailure?)> productPerformance();
  Future<(List<AgingRow>, ReportingFailure?)> customerAging();
  Future<(List<AgingRow>, ReportingFailure?)> supplierAging();
  Future<(List<DailySalesRow>, ReportingFailure?)> dailySales({
    String? from,
    String? to,
  });

  Future<(List<ReportSchedule>, ReportingFailure?)> schedules();
  Future<ReportingFailure?> upsertSchedule({
    String? id,
    required String reportType,
    required String name,
    required String frequency,
    required Map<String, dynamic> filters,
    required List<String> recipients,
    required String format,
    required bool active,
  });
  Future<(List<AiRecommendation>, ReportingFailure?)> pendingRecommendations();
  Future<ReportingFailure?> actOnRecommendation(String id, bool accept);
}
