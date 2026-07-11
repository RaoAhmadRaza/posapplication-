sealed class SalesFailure {
  String get message;
}

class InsufficientStockFailure extends SalesFailure {
  final String? productId;
  InsufficientStockFailure({this.productId});
  @override
  String get message => productId != null
      ? 'Insufficient stock for product $productId'
      : 'Insufficient stock.';
}

class CreditRequiresCustomerFailure extends SalesFailure {
  @override
  String get message => 'Credit sales require a customer.';
}

class CreditLimitExceededFailure extends SalesFailure {
  @override
  String get message =>
      'Credit limit exceeded. Collect a payment or raise the limit.';
}

class NoOpenSessionFailure extends SalesFailure {
  @override
  String get message => 'No open cashier session. Please open a session first.';
}

class ImeiNotAvailableFailure extends SalesFailure {
  final String? imei;
  ImeiNotAvailableFailure({this.imei});
  @override
  String get message =>
      imei != null ? 'IMEI not available: $imei' : 'IMEI not available.';
}

class PermissionDeniedFailure extends SalesFailure {
  @override
  String get message => 'You do not have permission to perform this action.';
}

class CustomerNotFoundFailure extends SalesFailure {
  @override
  String get message => 'Customer not found.';
}

class SessionAlreadyOpenFailure extends SalesFailure {
  @override
  String get message => 'You already have an open session on this branch.';
}

class SessionNotOpenFailure extends SalesFailure {
  @override
  String get message => 'Session is not open or not found.';
}

class ProductNotFoundFailure extends SalesFailure {
  final String? productId;
  ProductNotFoundFailure({this.productId});
  @override
  String get message => productId != null
      ? 'Product not found: $productId'
      : 'Product not found.';
}

class EmptyCartFailure extends SalesFailure {
  @override
  String get message => 'Cart is empty.';
}

class UnknownFailure extends SalesFailure {
  final String details;
  UnknownFailure(this.details);
  @override
  String get message => details;
}
