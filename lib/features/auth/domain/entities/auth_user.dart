class AuthUser {
  final String id;
  final String? email;
  final String? fullName;

  const AuthUser({
    required this.id,
    this.email,
    this.fullName,
  });
}
