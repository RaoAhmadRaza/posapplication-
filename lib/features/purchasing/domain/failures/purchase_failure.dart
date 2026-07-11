sealed class PurchaseFailure {
  String get message;
}

class PurchasePermissionDeniedFailure extends PurchaseFailure {
  @override
  String get message => 'You do not have permission to perform this action.';
}

class PurchaseBadTransitionFailure extends PurchaseFailure {
  @override
  String get message => 'That action is not allowed in the current state.';
}

class PurchaseOverReceiptFailure extends PurchaseFailure {
  @override
  String get message => 'Received quantity exceeds the ordered quantity.';
}

class PurchaseOverpaymentFailure extends PurchaseFailure {
  @override
  String get message => 'Payment exceeds the invoice balance.';
}

class PurchaseGrnMismatchFailure extends PurchaseFailure {
  @override
  String get message => 'Invoice does not match the goods received.';
}

class PurchaseReturnExceedsReceivedFailure extends PurchaseFailure {
  @override
  String get message =>
      'Return quantity exceeds what was received (minus prior returns).';
}

class PurchaseImeiCountMismatchFailure extends PurchaseFailure {
  @override
  String get message =>
      'Scan exactly one IMEI per returned unit for serialized items.';
}

class PurchaseImeiNotFoundFailure extends PurchaseFailure {
  @override
  String get message =>
      'One or more IMEIs are not on hand for this product.';
}

class PurchaseNotFoundFailure extends PurchaseFailure {
  @override
  String get message => 'Record not found.';
}

class PurchaseUnknownFailure extends PurchaseFailure {
  final String details;
  PurchaseUnknownFailure(this.details);
  @override
  String get message => details;
}
