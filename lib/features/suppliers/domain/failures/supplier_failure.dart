sealed class SupplierFailure {
  String get message;
}

class SupplierPermissionDeniedFailure extends SupplierFailure {
  @override
  String get message => 'You do not have permission to perform this action.';
}

class SupplierNotFoundFailure extends SupplierFailure {
  @override
  String get message => 'Supplier not found.';
}

class SupplierUnknownFailure extends SupplierFailure {
  final String details;
  SupplierUnknownFailure(this.details);
  @override
  String get message => details;
}
