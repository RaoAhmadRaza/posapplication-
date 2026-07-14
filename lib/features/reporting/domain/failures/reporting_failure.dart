sealed class ReportingFailure {
  String get message;
}

class ReportingLoadFailure extends ReportingFailure {
  @override
  String get message => 'Could not load report data.';
}

class ReportingUnknownFailure extends ReportingFailure {
  final String details;
  ReportingUnknownFailure(this.details);
  @override
  String get message => details;
}
