sealed class DashboardFailure {
  String get message;
}

class DashboardLoadFailure extends DashboardFailure {
  @override
  String get message => 'Could not load dashboard data.';
}

class DashboardUnknownFailure extends DashboardFailure {
  final String details;
  DashboardUnknownFailure(this.details);
  @override
  String get message => details;
}
