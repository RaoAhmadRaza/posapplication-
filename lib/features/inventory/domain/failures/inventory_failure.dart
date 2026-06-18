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

class InsufficientStockFailure extends InventoryFailure {
  @override
  String get message => 'Insufficient stock to complete this movement.';
}

class WarehouseHasStockFailure extends InventoryFailure {
  @override
  String get message => 'Cannot delete a warehouse that still has stock.';
}

class DuplicateImeiFailure extends InventoryFailure {
  @override
  String get message => 'This IMEI is already registered.';
}

class ApprovalRequiredFailure extends InventoryFailure {
  @override
  String get message => 'This adjustment requires approval before posting.';
}

class InvalidTransitionFailure extends InventoryFailure {
  @override
  String get message => 'This status transition is not allowed.';
}

class UnknownFailure extends InventoryFailure {
  final String details;
  UnknownFailure(this.details);

  @override
  String get message => details;
}
