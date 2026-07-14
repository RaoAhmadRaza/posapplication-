sealed class HrFailure {
  String get message;
}

class HrPermissionDeniedFailure extends HrFailure {
  @override
  String get message => 'You do not have permission to perform this action.';
}

class HrCodeTakenFailure extends HrFailure {
  @override
  String get message => 'That employee code is already in use.';
}

class HrEmpNotFoundFailure extends HrFailure {
  @override
  String get message => 'Employee not found.';
}

class HrEditReasonRequiredFailure extends HrFailure {
  @override
  String get message => 'A reason is required to edit an existing record.';
}

class HrLeaveNotPendingFailure extends HrFailure {
  @override
  String get message => 'Only a pending leave can be decided.';
}

class HrRunNotDraftFailure extends HrFailure {
  @override
  String get message => 'The payroll run must be a draft for this action.';
}

class HrRunNotCalculatedFailure extends HrFailure {
  @override
  String get message => 'The payroll run must be calculated first.';
}

class HrRunNotApprovedFailure extends HrFailure {
  @override
  String get message => 'The payroll run must be approved before disbursing.';
}

class HrPeriodExistsFailure extends HrFailure {
  @override
  String get message => 'A payroll run for this period already exists.';
}

class HrNegativeNetFailure extends HrFailure {
  @override
  String get message => 'Net pay cannot be negative.';
}

class HrUnknownFailure extends HrFailure {
  final String details;
  HrUnknownFailure(this.details);
  @override
  String get message => details;
}
