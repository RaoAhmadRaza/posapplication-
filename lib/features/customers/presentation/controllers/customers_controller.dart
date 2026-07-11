import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_ledger.dart';
import '../../domain/entities/receivables_aging.dart';
import '../../domain/failures/customer_failure.dart';
import '../../domain/usecases/load_customers.dart';
import '../../domain/usecases/create_customer.dart';
import '../../domain/usecases/update_customer.dart';
import '../../domain/usecases/soft_delete_customer.dart';
import '../../domain/usecases/load_customer_ledger.dart';
import '../../domain/usecases/load_receivables_aging.dart';

final customersProvider =
    AsyncNotifierProvider<CustomersController, List<Customer>>(
  CustomersController.new,
);

class CustomersController extends AsyncNotifier<List<Customer>> {
  String? _query;
  CustomerStatus? _status;

  CustomerStatus? get statusFilter => _status;

  @override
  Future<List<Customer>> build() async {
    final (customers, failure) = await ref
        .read(loadCustomersUseCaseProvider)
        .call(query: _query, status: _status);
    if (failure != null) throw failure;
    return customers;
  }

  Future<void> search(String q) async {
    _query = q.isEmpty ? null : q;
    await _reload();
  }

  Future<void> setStatus(CustomerStatus? status) async {
    _status = status;
    await _reload();
  }

  void refresh() => ref.invalidateSelf();

  Future<void> _reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final (customers, failure) = await ref
          .read(loadCustomersUseCaseProvider)
          .call(query: _query, status: _status);
      if (failure != null) throw failure;
      return customers;
    });
  }

  Future<CustomerFailure?> create(Map<String, dynamic> data) async {
    final (_, failure) =
        await ref.read(createCustomerUseCaseProvider).call(data);
    if (failure != null) return failure;
    ref.invalidateSelf();
    ref.invalidate(receivablesAgingProvider);
    return null;
  }

  Future<CustomerFailure?> edit(String id, Map<String, dynamic> data) async {
    final (_, failure) =
        await ref.read(updateCustomerUseCaseProvider).call(id, data);
    if (failure != null) return failure;
    ref.invalidateSelf();
    ref.invalidate(customerLedgerProvider(id));
    ref.invalidate(receivablesAgingProvider);
    return null;
  }

  Future<CustomerFailure?> remove(String id) async {
    final (_, failure) =
        await ref.read(softDeleteCustomerUseCaseProvider).call(id);
    if (failure != null) return failure;
    ref.invalidateSelf();
    return null;
  }
}

/// Per-customer ledger for the detail page (invoice debits / payment credits).
final customerLedgerProvider =
    FutureProvider.autoDispose.family<CustomerLedger, String>((ref, id) async {
  final (ledger, failure) =
      await ref.read(loadCustomerLedgerUseCaseProvider).call(id);
  if (failure != null) throw failure;
  return ledger!;
});

/// Tenant-wide receivables aging — drives the per-row balance hint in the list.
final receivablesAgingProvider =
    FutureProvider.autoDispose<ReceivablesAging>((ref) async {
  final (aging, failure) =
      await ref.read(loadReceivablesAgingUseCaseProvider).call();
  if (failure != null) throw failure;
  return aging!;
});

/// Outstanding (guard-basis) balance for one customer — drives the POS
/// remaining-credit chip. Best-effort: 0 on failure, never blocks the sale UI.
final customerOutstandingProvider =
    FutureProvider.autoDispose.family<double, String>((ref, id) async {
  final (ledger, failure) =
      await ref.read(loadCustomerLedgerUseCaseProvider).call(id);
  if (failure != null || ledger == null) return 0;
  return ledger.outstanding;
});
