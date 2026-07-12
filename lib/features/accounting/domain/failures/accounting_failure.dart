sealed class AccountingFailure {
  String get message;
}

class AccountingPermissionDeniedFailure extends AccountingFailure {
  @override
  String get message => 'You do not have permission to perform this action.';
}

class AccountingUnbalancedFailure extends AccountingFailure {
  @override
  String get message => 'Debits and credits must be equal.';
}

class AccountingPeriodClosedFailure extends AccountingFailure {
  @override
  String get message => 'The accounting period is closed.';
}

class AccountingAccountNotFoundFailure extends AccountingFailure {
  @override
  String get message => 'One or more accounts could not be found.';
}

class AccountingNotFoundFailure extends AccountingFailure {
  @override
  String get message => 'Record not found.';
}

class AccountingPeriodLockedFailure extends AccountingFailure {
  @override
  String get message => 'This period is locked and cannot be changed.';
}

class AccountingPeriodAlreadyClosedFailure extends AccountingFailure {
  @override
  String get message => 'This period is already closed.';
}

class AccountingAlreadyCompletedFailure extends AccountingFailure {
  @override
  String get message => 'This reconciliation is already completed.';
}

class AccountingUnknownFailure extends AccountingFailure {
  final String details;
  AccountingUnknownFailure(this.details);
  @override
  String get message => details;
}
