class AuthProfile {
  final String fullName;
  final String email;
  final String? roleId;
  final String? roleName;
  final String? tenantId;
  final String? tenantName;

  const AuthProfile({
    required this.fullName,
    required this.email,
    this.roleId,
    this.roleName,
    this.tenantId,
    this.tenantName,
  });
}
