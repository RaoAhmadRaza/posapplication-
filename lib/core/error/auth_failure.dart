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

class SessionExpiredFailure extends AuthFailure {
  @override
  String get message => 'Session expired. Please log in again.';
}

class OtpExpiredFailure extends AuthFailure {
  @override
  String get message => 'That code expired or was already used — tap Resend for a new one.';
}

class ServerErrorFailure extends AuthFailure {
  @override
  String get message => 'Something went wrong. Please try again later.';
}

class UnknownFailure extends AuthFailure {
  final String details;
  UnknownFailure(this.details);

  @override
  String get message => details;
}

class RecoveryState extends ChangeNotifier {
  static final instance = RecoveryState();

  bool _isRecovering = false;
  bool get isRecovering => _isRecovering;

  set isRecovering(bool v) {
    if (_isRecovering != v) {
      _isRecovering = v;
      notifyListeners();
    }
  }
}
