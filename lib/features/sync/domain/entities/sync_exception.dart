/// An OPEN row from server sync_exceptions — a terminal replay failure that a
/// human works (e.g. adjust stock), NOT a JSON merge.
class SyncException {
  const SyncException({
    required this.id,
    required this.outboxId,
    required this.errorCode,
    this.errorDetail,
    required this.payload,
    required this.createdAt,
  });

  final String id;
  final String outboxId;
  final String errorCode;
  final String? errorDetail;
  final Map<String, dynamic> payload; // frozen create_sale args (items → product ids)
  final String createdAt;

  /// Product ids referenced by the intent — deep-linked to inventory so an admin
  /// can adjust stock (the actual resolution).
  List<String> get productIds {
    final items = payload['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => e['product_id']?.toString())
        .whereType<String>()
        .toList();
  }
}
