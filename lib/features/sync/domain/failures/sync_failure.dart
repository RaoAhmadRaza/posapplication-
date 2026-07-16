/// Typed failures for the sync feature. Mirrors the sealed-failure pattern used
/// across the app (ApprovalFailure/SalesFailure) — never swallow, always map.
sealed class SyncFailure {
  const SyncFailure();
  String get message;
}

class SyncNetworkFailure extends SyncFailure {
  const SyncNetworkFailure();
  @override
  String get message => 'No connection — working offline.';
}

class SyncPermissionFailure extends SyncFailure {
  const SyncPermissionFailure();
  @override
  String get message => 'You do not have permission to sync.';
}

class SyncCacheFailure extends SyncFailure {
  const SyncCacheFailure(this.details);
  final String details;
  @override
  String get message => 'Local cache error: $details';
}

class SyncUnknownFailure extends SyncFailure {
  const SyncUnknownFailure(this.details);
  final String details;
  @override
  String get message => details;
}
