/// A customer row from the Class A reference cache (sync_pull_reference.customers),
/// persisted locally for the offline customer picker.
class CachedCustomer {
  const CachedCustomer({
    required this.id,
    required this.name,
    this.phone,
    required this.creditLimit,
    required this.status,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? phone;
  final double creditLimit;
  final String status;
  final String updatedAt;
}
