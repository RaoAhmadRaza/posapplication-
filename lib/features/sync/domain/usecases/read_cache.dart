import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../entities/cached_customer.dart';
import '../entities/cached_product.dart';
import '../failures/sync_failure.dart';
import '../repositories/sync_repository.dart';
import '../../data/repositories/sync_repository_impl.dart';

/// Cache-first reads (product search / price lookup / customer picker) and the
/// pending-intent count. Grouped: all are one-line passthroughs over the same repo.
class SearchCachedProducts {
  SearchCachedProducts(this._repo);
  final SyncRepository _repo;
  Future<(List<CachedProduct>, SyncFailure?)> call(String query) =>
      _repo.searchProducts(query);
}

class ProductById {
  ProductById(this._repo);
  final SyncRepository _repo;
  Future<(CachedProduct?, SyncFailure?)> call(String id) => _repo.productById(id);
}

class LoadCachedCustomers {
  LoadCachedCustomers(this._repo);
  final SyncRepository _repo;
  Future<(List<CachedCustomer>, SyncFailure?)> call() => _repo.loadCustomers();
}

class PendingIntentCount {
  PendingIntentCount(this._repo);
  final SyncRepository _repo;
  Future<(int, SyncFailure?)> call() => _repo.pendingIntentCount();
}

final searchCachedProductsUseCaseProvider = Provider(
    (ref) => SearchCachedProducts(ref.read(syncRepositoryProvider)));
final productByIdUseCaseProvider =
    Provider((ref) => ProductById(ref.read(syncRepositoryProvider)));
final loadCachedCustomersUseCaseProvider =
    Provider((ref) => LoadCachedCustomers(ref.read(syncRepositoryProvider)));
final pendingIntentCountUseCaseProvider =
    Provider((ref) => PendingIntentCount(ref.read(syncRepositoryProvider)));
