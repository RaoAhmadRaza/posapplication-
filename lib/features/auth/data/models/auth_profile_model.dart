import '../../domain/entities/auth_profile.dart';

class AuthProfileModel {
  static AuthProfile fromJson(Map<String, dynamic> json) {
    final roles = json['roles'] as Map<String, dynamic>?;
    final tenants = json['tenants'] as Map<String, dynamic>?;

    return AuthProfile(
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      roleName: roles?['name'] as String?,
      tenantName: tenants?['name'] as String?,
    );
  }
}
