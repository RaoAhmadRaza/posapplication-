sealed class InventoryFailure {
  String get message;
}

class NotFoundFailure extends InventoryFailure {
  @override
  String get message => 'The requested item was not found.';
}

class DuplicateSkuFailure extends InventoryFailure {
  @override
  String get message => 'A product with this SKU or barcode already exists.';
}

class PermissionDeniedFailure extends InventoryFailure {
  @override
  String get message => 'You do not have permission to perform this action.';
}

class NetworkFailure extends InventoryFailure {
  @override
  String get message => 'Network error. Please check your connection.';
}

class UnknownFailure extends InventoryFailure {
  final String details;
  UnknownFailure(this.details);

  @override
  String get message => details;
}
