import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/load_session_sales.dart';

/// Live sales total (sum of invoices.grand_total) for a cashier session.
/// Throws the mapped SalesFailure on error so the POS banner shows an error
/// state instead of a silent zero. autoDispose so a fresh POS page refetches.
final sessionSalesProvider =
    FutureProvider.autoDispose.family<double, String>((ref, sessionId) async {
  final (map, failure) =
      await ref.read(loadSessionSalesUseCaseProvider).call(sessionId);
  if (failure != null) throw failure;
  return (map?['total_sales'] as num?)?.toDouble() ?? 0;
});
