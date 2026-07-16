/// An offline SALE intent queued in the local outbox. The device NEVER creates
/// an invoice — it appends this intent carrying a client-generated
/// idempotency_key (the whole replay contract), the true client_created_at, and
/// a provisional local_ref for the receipt. Replay (→ create_sale) is D7.2.
class SaleIntent {
  const SaleIntent({
    required this.id,
    required this.idempotencyKey,
    required this.payload,
    required this.clientCreatedAt,
    required this.localRef,
    this.status = 'PENDING',
  });

  final String id;
  final String idempotencyKey;
  final Map<String, dynamic> payload; // create_sale args verbatim
  final String clientCreatedAt; // UTC ISO-8601
  final String localRef;
  final String status;
}
