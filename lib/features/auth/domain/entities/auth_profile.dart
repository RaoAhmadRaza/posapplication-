class AuthProfile {
  final String fullName;
  final String email;
  final String? roleName;
  final String? tenantName;

  const AuthProfile({
    required this.fullName,
    required this.email,
    this.roleName,
    this.tenantName,
  });
}
