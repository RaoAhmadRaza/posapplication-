import '../entities/cached_customer.dart';
import '../entities/cached_product.dart';
import '../entities/outbox_entry.dart';
import '../entities/sale_intent.dart';
import '../entities/sync_exception.dart';
import '../failures/sync_failure.dart';

typedef DrainSummary = ({int applied, int abandoned, int failed});

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

  /// Count of intents still awaiting replay (PENDING or retryable FAILED).
  Future<(int, SyncFailure?)> pendingIntentCount();

  /// Drain the outbox OLDEST-FIRST, ONE AT A TIME (never parallel): push each
  /// intent to the server, replay it, and reconcile the result locally
  /// (applied → DONE + real invoice number; terminal → ABANDONED; transient →
  /// FAILED for backoff). Returns per-run counts.
  Future<(DrainSummary, SyncFailure?)> drainOutbox();

  /// All local outbox rows for the status sheet (newest first).
  Future<(List<OutboxEntry>, SyncFailure?)> loadIntents();

  /// Reconciliation: find an intent by provisional local_ref or real invoice number.
  Future<(List<OutboxEntry>, SyncFailure?)> findByRef(String query);

  /// OPEN server sync_exceptions (terminal failures for a human to resolve).
  Future<(List<SyncException>, SyncFailure?)> loadOpenExceptions();

  /// Resolve an exception with a note (gated sync:resolve server-side).
  Future<SyncFailure?> resolveException(String id, String note);

  /// Re-queue a stuck intent and replay it (gated sync:resolve server-side).
  /// The idempotency key guarantees at most one invoice.
  Future<SyncFailure?> retryIntent(String outboxId);

  /// Timestamp of the last successful drain, if any.
  Future<String?> lastSyncAt();
}
