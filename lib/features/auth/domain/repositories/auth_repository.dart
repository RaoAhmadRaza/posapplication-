import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/auth_failure.dart';
import '../entities/auth_profile.dart';
import '../entities/branch.dart';
import '../entities/permission.dart';

class SignUpResult {
  final String? emailNeedingConfirmation;
  const SignUpResult._({this.emailNeedingConfirmation});

  factory SignUpResult.success() => const SignUpResult._();
  factory SignUpResult.needsConfirmation(String email) =>
      SignUpResult._(emailNeedingConfirmation: email);
}

class SignInResult {
  final String? emailNeedingConfirmation;
  const SignInResult._({this.emailNeedingConfirmation});

  factory SignInResult.success() => const SignInResult._();
  factory SignInResult.needsConfirmation(String email) =>
      SignInResult._(emailNeedingConfirmation: email);
}

abstract class AuthRepository {
  Future<(SignUpResult, AuthFailure?)> signUp({
    required String email,
    required String password,
    String? fullName,
    String? businessName,
    bool demoMode,
  });

  Future<(SignInResult, AuthFailure?)> signIn({
    required String email,
    required String password,
  });

  Future<AuthFailure?> signOut();

  Future<AuthFailure?> verifyEmailOtp({
    required String email,
    required String code,
  });

  Future<AuthFailure?> requestPasswordReset(String email);

  Future<AuthFailure?> verifyRecoveryOtp({
    required String email,
    required String code,
  });

  Future<AuthFailure?> setNewPassword(String newPassword);

  Future<AuthFailure?> resendCode({
    required String email,
    required bool isRecovery,
  });

  Stream<AuthState> watchAuthState();

  Future<(AuthProfile?, AuthFailure?)> loadProfile(String userId);

  Future<(List<Permission>, AuthFailure?)> loadPermissions(String roleId);

  Future<(List<Branch>, AuthFailure?)> loadUserBranches(String userId);
}
