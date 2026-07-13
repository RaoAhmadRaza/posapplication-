sealed class RepairFailure {
  String get message;
}

class RepairPermissionDeniedFailure extends RepairFailure {
  @override
  String get message => 'You do not have permission to perform this action.';
}

class RepairInvalidTransitionFailure extends RepairFailure {
  @override
  String get message => 'That status change is not allowed from here.';
}

class RepairJobNotReadyFailure extends RepairFailure {
  @override
  String get message => 'The job must be READY before it can be closed.';
}

class RepairJobClosedFailure extends RepairFailure {
  @override
  String get message => 'This job is already closed.';
}

/// IN_REPAIR/etc → DELIVERED attempted directly: must close & invoice instead.
class RepairUseCloseToDeliverFailure extends RepairFailure {
  @override
  String get message => 'Use “Close & Invoice” to deliver a repair.';
}

/// Warranty claim attempted on a job that isn't DELIVERED.
class RepairNotDeliveredFailure extends RepairFailure {
  @override
  String get message => 'Only a delivered job can start a warranty claim.';
}

/// Warranty claim attempted on a job whose warranty has lapsed.
class RepairWarrantyExpiredFailure extends RepairFailure {
  @override
  String get message => 'This job is out of warranty.';
}

/// Paid amount exceeds the invoice grand total.
class RepairOverpaymentFailure extends RepairFailure {
  @override
  String get message => 'Paid amount cannot exceed the total.';
}

class RepairNotFoundFailure extends RepairFailure {
  @override
  String get message => 'Record not found.';
}

class RepairUnknownFailure extends RepairFailure {
  final String details;
  RepairUnknownFailure(this.details);
  @override
  String get message => details;
}
