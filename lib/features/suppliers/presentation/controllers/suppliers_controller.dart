import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/entities/supplier_ledger.dart';
import '../../domain/entities/payables_aging.dart';
import '../../domain/failures/supplier_failure.dart';
import '../../domain/usecases/load_suppliers.dart';
import '../../domain/usecases/create_supplier.dart';
import '../../domain/usecases/update_supplier.dart';
import '../../domain/usecases/soft_delete_supplier.dart';
import '../../domain/usecases/load_supplier_ledger.dart';
import '../../domain/usecases/load_payables_aging.dart';

final suppliersProvider =
    AsyncNotifierProvider<SuppliersController, List<Supplier>>(
  SuppliersController.new,
);

class SuppliersController extends AsyncNotifier<List<Supplier>> {
  String? _query;
  SupplierStatus? _status;

  SupplierStatus? get statusFilter => _status;

  @override
  Future<List<Supplier>> build() async {
    final (suppliers, failure) = await ref
        .read(loadSuppliersUseCaseProvider)
        .call(query: _query, status: _status);
    if (failure != null) throw failure;
    return suppliers;
  }

  Future<void> search(String q) async {
    _query = q.isEmpty ? null : q;
    await _reload();
  }

  Future<void> setStatus(SupplierStatus? status) async {
    _status = status;
    await _reload();
  }

  void refresh() => ref.invalidateSelf();

  Future<void> _reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final (suppliers, failure) = await ref
          .read(loadSuppliersUseCaseProvider)
          .call(query: _query, status: _status);
      if (failure != null) throw failure;
      return suppliers;
    });
  }

  Future<SupplierFailure?> create(Map<String, dynamic> data) async {
    final (_, failure) =
        await ref.read(createSupplierUseCaseProvider).call(data);
    if (failure != null) return failure;
    ref.invalidateSelf();
    return null;
  }

  Future<SupplierFailure?> edit(String id, Map<String, dynamic> data) async {
    final (_, failure) =
        await ref.read(updateSupplierUseCaseProvider).call(id, data);
    if (failure != null) return failure;
    ref.invalidateSelf();
    ref.invalidate(supplierLedgerProvider(id));
    return null;
  }

  Future<SupplierFailure?> remove(String id) async {
    final (_, failure) =
        await ref.read(softDeleteSupplierUseCaseProvider).call(id);
    if (failure != null) return failure;
    ref.invalidateSelf();
    return null;
  }
}

/// Per-supplier ledger for the detail page (invoice debits / payment credits).
final supplierLedgerProvider =
    FutureProvider.autoDispose.family<SupplierLedger, String>((ref, id) async {
  final (ledger, failure) =
      await ref.read(loadSupplierLedgerUseCaseProvider).call(id);
  if (failure != null) throw failure;
  return ledger!;
});

/// Tenant-wide payables aging — drives the per-row payable hint in the list.
final payablesAgingProvider =
    FutureProvider.autoDispose<PayablesAging>((ref) async {
  final (aging, failure) =
      await ref.read(loadPayablesAgingUseCaseProvider).call();
  if (failure != null) throw failure;
  return aging!;
});
