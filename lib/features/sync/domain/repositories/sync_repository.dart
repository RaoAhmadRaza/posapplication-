import '../entities/cached_customer.dart';
import '../entities/cached_product.dart';
import '../entities/sale_intent.dart';
import '../failures/sync_failure.dart';

/// Reference-cache read/pull + outbox write. Replay is deliberately absent (D7.2).
/// Returns follow the app convention: records `(data, Failure?)`, or bare
/// `Failure?` for mutations (null == success). No exceptions leak past here.
abstract class SyncRepository {
  /// Pull the Class A delta from sync_pull_reference (using the stored
  /// watermark), persist to the local cache, evict rows arriving deleted, and
  /// advance the watermark. Mutation → returns a failure or null.
  Future<SyncFailure?> pullReference();

  /// Cache-first product search (name/sku/barcode contains, active only).
  Future<(List<CachedProduct>, SyncFailure?)> searchProducts(String query);

  /// Cache-first product lookup by id (price resolution offline).
  Future<(CachedProduct?, SyncFailure?)> productById(String id);

  /// Cache-first customer list for the offline picker.
  Future<(List<CachedCustomer>, SyncFailure?)> loadCustomers();

  /// Append a SALE intent to the local outbox (offline write path).
  Future<SyncFailure?> enqueueSaleIntent(SaleIntent intent);

  /// Count of intents still awaiting replay (PENDING).
  Future<(int, SyncFailure?)> pendingIntentCount();
}
