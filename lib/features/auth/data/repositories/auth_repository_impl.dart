import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/auth_failure.dart';
import '../../domain/entities/auth_profile.dart';
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
          msg.contains('429')) {
        return TooManyRequestsFailure();
      }
      if (msg.contains('token has expired') ||
          msg.contains('otp expired') ||
          msg.contains('invalid otp')) {
        return OtpExpiredFailure();
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
  }) async {
    try {
      final (_, needsConfirmation) = await _ds.signUp(
        email: email,
        password: password,
        fullName: fullName,
        businessName: businessName,
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
}
