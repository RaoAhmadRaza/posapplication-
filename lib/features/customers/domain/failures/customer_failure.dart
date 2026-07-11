sealed class CustomerFailure {
  String get message;
}

class CustomerPermissionDeniedFailure extends CustomerFailure {
  @override
  String get message => 'You do not have permission to perform this action.';
}

class CustomerNotFoundFailure extends CustomerFailure {
  @override
  String get message => 'Customer not found.';
}

class CustomerUnknownFailure extends CustomerFailure {
  final String details;
  CustomerUnknownFailure(this.details);
  @override
  String get message => details;
}
