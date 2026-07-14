import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/reporting.dart';
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
