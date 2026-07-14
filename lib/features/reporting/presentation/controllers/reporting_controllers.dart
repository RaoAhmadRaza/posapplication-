import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/ai_recommendation.dart';
import '../../domain/entities/report_schedule.dart';
import '../../domain/entities/reporting.dart';
import '../../domain/failures/reporting_failure.dart';
import '../../domain/usecases/reporting_usecases.dart';

Future<T> _unwrap<T>((T, Object?) result) {
  final (data, failure) = result;
  if (failure != null) throw failure;
  return Future.value(data);
}

final inventoryValuationProvider =
    FutureProvider.autoDispose<List<InventoryValuationRow>>((ref) async {
  return _unwrap(await ref.read(loadInventoryValuationProvider).call());
});

final productPerformanceProvider =
    FutureProvider.autoDispose<List<ProductPerformanceRow>>((ref) async {
  return _unwrap(await ref.read(loadProductPerformanceProvider).call());
});

final customerAgingProvider =
    FutureProvider.autoDispose<List<AgingRow>>((ref) async {
  return _unwrap(await ref.read(loadCustomerAgingProvider).call());
});

final supplierAgingProvider =
    FutureProvider.autoDispose<List<AgingRow>>((ref) async {
  return _unwrap(await ref.read(loadSupplierAgingProvider).call());
});

/// Date range for the trend report; null bounds = unbounded.
typedef TrendRange = ({String? from, String? to});

final dailySalesProvider = FutureProvider.autoDispose
    .family<List<DailySalesRow>, TrendRange>((ref, range) async {
  return _unwrap(
    await ref.read(loadDailySalesProvider).call(from: range.from, to: range.to),
  );
});

final reportSchedulesProvider =
    AsyncNotifierProvider<SchedulesController, List<ReportSchedule>>(
  SchedulesController.new,
);

class SchedulesController extends AsyncNotifier<List<ReportSchedule>> {
  @override
  Future<List<ReportSchedule>> build() async =>
      _unwrap(await ref.read(loadSchedulesProvider).call());

  Future<ReportingFailure?> upsert({
    String? id,
    required String reportType,
    required String name,
    required String frequency,
    required Map<String, dynamic> filters,
    required List<String> recipients,
    required String format,
    required bool active,
  }) async {
    final failure = await ref.read(upsertScheduleProvider).call(
          id: id,
          reportType: reportType,
          name: name,
          frequency: frequency,
          filters: filters,
          recipients: recipients,
          format: format,
          active: active,
        );
    if (failure == null) ref.invalidateSelf();
    return failure;
  }
}

final pendingRecommendationsProvider =
    AsyncNotifierProvider<RecommendationsController, List<AiRecommendation>>(
  RecommendationsController.new,
);

class RecommendationsController extends AsyncNotifier<List<AiRecommendation>> {
  @override
  Future<List<AiRecommendation>> build() async =>
      _unwrap(await ref.read(loadPendingRecommendationsProvider).call());

  Future<ReportingFailure?> act(String id, bool accept) async {
    final failure =
        await ref.read(actOnRecommendationProvider).call(id, accept);
    if (failure == null) ref.invalidateSelf();
    return failure;
  }
}
