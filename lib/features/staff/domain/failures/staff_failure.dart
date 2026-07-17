/// Typed failures for the staff-onboarding feature. Messages are user-facing.
sealed class StaffFailure {
  String get message;
}

class StaffPermissionDeniedFailure extends StaffFailure {
  @override
  String get message => 'You do not have permission to do this.';
}

class StaffCannotGrantFailure extends StaffFailure {
  @override
  String get message =>
      'You can only grant permissions you hold yourself.';
}

class StaffHierarchyFailure extends StaffFailure {
  @override
  String get message => 'You cannot assign a role at or above your own level.';
}

class StaffLastAdminFailure extends StaffFailure {
  @override
  String get message =>
      'This is the last admin — assign another admin before changing this role.';
}

class StaffNotFoundFailure extends StaffFailure {
  @override
  String get message => 'That record was not found or is no longer available.';
}

class StaffValidationFailure extends StaffFailure {
  StaffValidationFailure(this.details);
  final String details;
  @override
  String get message => details;
}

class StaffUnknownFailure extends StaffFailure {
  StaffUnknownFailure(this.details);
  final String details;
  @override
  String get message => details;
}
