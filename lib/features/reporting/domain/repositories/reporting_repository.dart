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
}
