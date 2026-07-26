sealed class SettingsFailure {
  String get message;
}

class SettingsLoadFailure extends SettingsFailure {
  @override
  String get message => 'Unable to load settings.';
}

class SettingsPermissionFailure extends SettingsFailure {
  @override
  String get message => 'You do not have permission to change settings.';
}

class SettingsNotFoundFailure extends SettingsFailure {
  @override
  String get message => 'The record could not be found.';
}

class SettingsUnknownFailure extends SettingsFailure {
  final String details;
  SettingsUnknownFailure(this.details);
  @override
  String get message => details;
}
