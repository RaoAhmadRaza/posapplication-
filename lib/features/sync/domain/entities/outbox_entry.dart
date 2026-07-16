/// A local outbox row as shown in the status sheet / reconciliation search.
/// status: PENDING · FAILED · DONE · ABANDONED.
class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.idempotencyKey,
    required this.localRef,
    this.invoiceNumber,
    required this.status,
    required this.clientCreatedAt,
    this.attempts = 0,
    this.lastError,
  });

  final String id;
  final String idempotencyKey;
  final String localRef;
  final String? invoiceNumber; // real invoice number once applied (reconciliation)
  final String status;
  final String clientCreatedAt;
  final int attempts;
  final String? lastError;
}
