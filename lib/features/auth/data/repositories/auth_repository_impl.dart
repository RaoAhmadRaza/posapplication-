import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/auth_failure.dart';
import '../../domain/entities/auth_profile.dart';
import '../../domain/entities/branch.dart';
import '../../domain/entities/permission.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_profile_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.read(authRemoteDataSourceProvider));
});

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _ds;

  AuthRepositoryImpl(this._ds);

  AuthFailure _mapError(Object e) {
    if (e is AuthException) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid login credentials') ||
          msg.contains('invalid email or password')) {
        return InvalidCredentialsFailure();
      }
      if (msg.contains('email not confirmed')) {
        return EmailNotConfirmedFailure('');
      }
      if (msg.contains('already registered') ||
          msg.contains('already exists') ||
          msg.contains('already been registered') ||
          msg.contains('duplicate')) {
        return EmailAlreadyInUseFailure();
      }
      if (msg.contains('too many requests') ||
          msg.contains('rate limit') ||
          msg.contains('429') ||
          msg.contains('security purposes') ||
          msg.contains('request this after')) {
        return TooManyRequestsFailure();
      }
      if (msg.contains('token has expired') || msg.contains('otp expired')) {
        return OtpExpiredFailure();
      }
      if (msg.contains('invalid otp')) {
        return InvalidOtpFailure();
      }
      if (msg.contains('expired') || msg.contains('session')) {
        return SessionExpiredFailure();
      }
      return UnknownFailure(e.message);
    }
    return UnknownFailure(e.toString());
  }

  @override
  Future<(SignUpResult, AuthFailure?)> signUp({
    required String email,
    required String password,
    String? fullName,
    String? businessName,
    bool demoMode = false,
  }) async {
    try {
      final (_, needsConfirmation) = await _ds.signUp(
        email: email,
        password: password,
        fullName: fullName,
        businessName: businessName,
        demoMode: demoMode,
      );
      if (needsConfirmation) {
        return (SignUpResult.needsConfirmation(email), null);
      }
      return (SignUpResult.success(), null);
    } catch (e) {
      return (SignUpResult.success(), _mapError(e));
    }
  }

  @override
  Future<(SignInResult, AuthFailure?)> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _ds.signIn(email: email, password: password);
      return (SignInResult.success(), null);
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('email not confirmed')) {
        return (SignInResult.needsConfirmation(email), null);
      }
      return (SignInResult.success(), _mapError(e));
    } catch (e) {
      return (SignInResult.success(), _mapError(e));
    }
  }

  @override
  Future<AuthFailure?> signOut() async {
    try {
      await _ds.signOut();
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<AuthFailure?> verifyEmailOtp({
    required String email,
    required String code,
  }) async {
    try {
      await _ds.verifyEmailOtp(email: email, code: code);
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<AuthFailure?> requestPasswordReset(String email) async {
    try {
      await _ds.requestPasswordReset(email);
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<AuthFailure?> verifyRecoveryOtp({
    required String email,
    required String code,
  }) async {
    try {
      await _ds.verifyRecoveryOtp(email: email, code: code);
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<AuthFailure?> setNewPassword(String newPassword) async {
    try {
      await _ds.setNewPassword(newPassword);
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<AuthFailure?> resendCode({
    required String email,
    required bool isRecovery,
  }) async {
    try {
      if (isRecovery) {
        await _ds.resendRecoveryCode(email);
      } else {
        await _ds.resendSignupCode(email);
      }
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Stream<AuthState> watchAuthState() => _ds.watchAuthState();

  @override
  Future<(AuthProfile?, AuthFailure?)> loadProfile(String userId) async {
    try {
      final json = await _ds.loadProfile(userId);
      return (AuthProfileModel.fromJson(json), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(List<Permission>, AuthFailure?)> loadPermissions(String roleId) async {
    try {
      final rows = await _ds.loadPermissions(roleId);
      final perms = rows.map((r) {
        return Permission(
          module: r['module'] as String,
          action: r['action'] as String,
          branchScope: r['branch_scope'] as String,
          granted: r['granted'] as bool,
        );
      }).toList();
      return (perms, null);
    } catch (e) {
      return (<Permission>[], _mapError(e));
    }
  }

  @override
  Future<(List<Branch>, AuthFailure?)> loadUserBranches(String userId) async {
    try {
      final rows = await _ds.loadUserBranches(userId);
      final branches = rows.map((r) {
        final b = r['branches'] as Map<String, dynamic>;
        return Branch(
          id: b['id'] as String,
          name: b['name'] as String,
          code: b['code'] as String,
          isMain: b['is_main'] as bool,
          isDefault: r['is_default'] as bool,
          currency: (b['currency'] ?? 'PKR') as String,
        );
      }).toList();
      return (branches, null);
    } catch (e) {
      return (<Branch>[], _mapError(e));
    }
  }
}
