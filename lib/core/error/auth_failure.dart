import 'package:flutter/foundation.dart';

sealed class AuthFailure {
  String get message;
}

class InvalidEmailFailure extends AuthFailure {
  @override
  String get message => 'Please enter a valid email address.';
}

class WeakPasswordFailure extends AuthFailure {
  @override
  String get message => 'Password must be at least 8 characters.';
}

class PasswordMismatchFailure extends AuthFailure {
  @override
  String get message => 'Passwords do not match.';
}

class InvalidCredentialsFailure extends AuthFailure {
  @override
  String get message => 'Invalid email or password.';
}

class EmailAlreadyInUseFailure extends AuthFailure {
  @override
  String get message => 'An account with this email already exists.';
}

class EmailNotConfirmedFailure extends AuthFailure {
  final String email;
  EmailNotConfirmedFailure(this.email);

  @override
  String get message => 'Email not confirmed. Please verify your email.';
}

class TooManyRequestsFailure extends AuthFailure {
  @override
  String get message => 'Too many attempts. Please wait and try again.';
}

class InvalidOtpFailure extends AuthFailure {
  @override
  String get message => 'Incorrect code, please try again.';
}

class MfaTransientFailure extends AuthFailure {
  @override
  String get message => 'Connection problem — check your network and try again.';
}

class OtpExpiredFailure extends AuthFailure {
  @override
  String get message => 'That code expired or was already used — request a new one.';
}

class SessionExpiredFailure extends AuthFailure {
  @override
  String get message => 'Session expired. Please log in again.';
}

class RecoverySessionExpiredFailure extends AuthFailure {
  @override
  String get message => 'Your reset session expired — please start forgot-password again.';
}

class ServerErrorFailure extends AuthFailure {
  @override
  String get message => 'The request could not be completed. Please try again later.';
}

class AccountLockedException implements Exception {
  final String lockedUntil;
  const AccountLockedException(this.lockedUntil);
}

class AccountLockedFailure extends AuthFailure {
  final String lockedUntil;
  AccountLockedFailure(this.lockedUntil);

  @override
  String get message {
    final dt = DateTime.tryParse(lockedUntil);
    if (dt == null) return 'Account is temporarily locked.';
    final remaining = dt.difference(DateTime.now().toUtc());
    if (remaining.inSeconds <= 0) return 'Account is temporarily locked.';
    if (remaining.inMinutes < 1) {
      return 'Account locked. Try again in ${remaining.inSeconds} seconds.';
    }
    return 'Account locked. Try again in ${remaining.inMinutes} minutes.';
  }
}

class UnknownFailure extends AuthFailure {
  final String details;
  UnknownFailure(this.details);

  @override
  String get message => details;
}

enum RecoveryStage { none, awaitingCode, codeVerified }

class RecoveryState extends ChangeNotifier {
  static final instance = RecoveryState();

  RecoveryStage _stage = RecoveryStage.none;
  RecoveryStage get stage => _stage;
  bool get isRecovering => _stage != RecoveryStage.none;

  set stage(RecoveryStage s) {
    if (_stage != s) {
      _stage = s;
      notifyListeners();
    }
  }

  void reset() => stage = RecoveryStage.none;
}
