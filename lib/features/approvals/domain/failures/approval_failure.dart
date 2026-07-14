sealed class ApprovalFailure {
  String get message;
}

class ApprovalPermissionDeniedFailure extends ApprovalFailure {
  @override
  String get message => 'You do not have permission to perform this action.';
}

class ApprovalRoleNotAllowedFailure extends ApprovalFailure {
  @override
  String get message => 'Your role cannot approve at this level.';
}

class ApprovalAlreadyActedFailure extends ApprovalFailure {
  @override
  String get message => 'You have already acted at this level.';
}

class ApprovalNotOpenFailure extends ApprovalFailure {
  @override
  String get message => 'This request is no longer open.';
}

class ApprovalRequestNotFoundFailure extends ApprovalFailure {
  @override
  String get message => 'Approval request not found.';
}

class ApprovalWorkflowNotFoundFailure extends ApprovalFailure {
  @override
  String get message => 'Approval workflow not found.';
}

class ApprovalLevelsRequiredFailure extends ApprovalFailure {
  @override
  String get message => 'A workflow needs at least one approval level.';
}

class ApprovalUnknownFailure extends ApprovalFailure {
  final String details;
  ApprovalUnknownFailure(this.details);
  @override
  String get message => details;
}
