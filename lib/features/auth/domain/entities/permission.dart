class Permission {
  final String module;
  final String action;
  final String branchScope;
  final bool granted;

  const Permission({
    required this.module,
    required this.action,
    required this.branchScope,
    required this.granted,
  });

  String get key => '$module:$action';
}
