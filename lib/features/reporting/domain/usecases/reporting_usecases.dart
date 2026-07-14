import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/reporting_repository_impl.dart';
import '../entities/ai_recommendation.dart';
import '../entities/report_schedule.dart';
import '../entities/reporting.dart';
import '../failures/reporting_failure.dart';
import '../repositories/reporting_repository.dart';

class LoadInventoryValuation {
  final ReportingRepository _r;
  LoadInventoryValuation(this._r);
  Future<(List<InventoryValuationRow>, ReportingFailure?)> call() =>
      _r.inventoryValuation();
}

class LoadProductPerformance {
  final ReportingRepository _r;
  LoadProductPerformance(this._r);
  Future<(List<ProductPerformanceRow>, ReportingFailure?)> call() =>
      _r.productPerformance();
}

class LoadCustomerAging {
  final ReportingRepository _r;
  LoadCustomerAging(this._r);
  Future<(List<AgingRow>, ReportingFailure?)> call() => _r.customerAging();
}

class LoadSupplierAging {
  final ReportingRepository _r;
  LoadSupplierAging(this._r);
  Future<(List<AgingRow>, ReportingFailure?)> call() => _r.supplierAging();
}

class LoadDailySales {
  final ReportingRepository _r;
  LoadDailySales(this._r);
  Future<(List<DailySalesRow>, ReportingFailure?)> call({
    String? from,
    String? to,
  }) =>
      _r.dailySales(from: from, to: to);
}

final loadInventoryValuationProvider = Provider(
    (ref) => LoadInventoryValuation(ref.read(reportingRepositoryProvider)));
final loadProductPerformanceProvider = Provider(
    (ref) => LoadProductPerformance(ref.read(reportingRepositoryProvider)));
final loadCustomerAgingProvider = Provider(
    (ref) => LoadCustomerAging(ref.read(reportingRepositoryProvider)));
final loadSupplierAgingProvider = Provider(
    (ref) => LoadSupplierAging(ref.read(reportingRepositoryProvider)));
final loadDailySalesProvider =
    Provider((ref) => LoadDailySales(ref.read(reportingRepositoryProvider)));

class LoadSchedules {
  final ReportingRepository _r;
  LoadSchedules(this._r);
  Future<(List<ReportSchedule>, ReportingFailure?)> call() => _r.schedules();
}

class UpsertSchedule {
  final ReportingRepository _r;
  UpsertSchedule(this._r);
  Future<ReportingFailure?> call({
    String? id,
    required String reportType,
    required String name,
    required String frequency,
    required Map<String, dynamic> filters,
    required List<String> recipients,
    required String format,
    required bool active,
  }) =>
      _r.upsertSchedule(
        id: id,
        reportType: reportType,
        name: name,
        frequency: frequency,
        filters: filters,
        recipients: recipients,
        format: format,
        active: active,
      );
}

class LoadPendingRecommendations {
  final ReportingRepository _r;
  LoadPendingRecommendations(this._r);
  Future<(List<AiRecommendation>, ReportingFailure?)> call() =>
      _r.pendingRecommendations();
}

class ActOnRecommendation {
  final ReportingRepository _r;
  ActOnRecommendation(this._r);
  Future<ReportingFailure?> call(String id, bool accept) =>
      _r.actOnRecommendation(id, accept);
}

final loadSchedulesProvider =
    Provider((ref) => LoadSchedules(ref.read(reportingRepositoryProvider)));
final upsertScheduleProvider =
    Provider((ref) => UpsertSchedule(ref.read(reportingRepositoryProvider)));
final loadPendingRecommendationsProvider = Provider(
    (ref) => LoadPendingRecommendations(ref.read(reportingRepositoryProvider)));
final actOnRecommendationProvider = Provider(
    (ref) => ActOnRecommendation(ref.read(reportingRepositoryProvider)));
