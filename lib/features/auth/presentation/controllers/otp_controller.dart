import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/auth_failure.dart';
import '../../domain/usecases/resend_code.dart';
import '../../domain/usecases/verify_email_otp.dart';
import '../../domain/usecases/verify_recovery_otp.dart';

class OtpState {
  final bool isLoading;
  final bool verifySucceeded;
  final AuthFailure? error;
  final int cooldownSeconds;

  const OtpState({
    this.isLoading = false,
    this.verifySucceeded = false,
    this.error,
    this.cooldownSeconds = 0,
  });

  OtpState copyWith({
    bool? isLoading,
    bool? verifySucceeded,
    AuthFailure? error,
    int? cooldownSeconds,
    bool clearError = false,
  }) {
    return OtpState(
      isLoading: isLoading ?? this.isLoading,
      verifySucceeded: verifySucceeded ?? this.verifySucceeded,
      error: clearError ? null : error,
      cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
    );
  }
}

final otpControllerProvider = NotifierProvider<OtpController, OtpState>(
  OtpController.new,
);

class OtpController extends Notifier<OtpState> {
  Timer? _cooldownTimer;

  @override
  OtpState build() {
    ref.onDispose(() {
      _cooldownTimer?.cancel();
    });
    return const OtpState();
  }

  Future<AuthFailure?> verify({
    required String email,
    required String code,
    required bool isRecovery,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    AuthFailure? failure;

    if (isRecovery) {
      RecoveryState.instance.isRecovering = true;
      try {
        failure = await ref.read(verifyRecoveryOtpUseCaseProvider).call(
              email: email,
              code: code,
            );
      } catch (_) {
        RecoveryState.instance.isRecovering = false;
        rethrow;
      }
    } else {
      failure = await ref.read(verifyEmailOtpUseCaseProvider).call(
            email: email,
            code: code,
          );
    }

    if (failure != null) {
      if (isRecovery) RecoveryState.instance.isRecovering = false;
      state = state.copyWith(isLoading: false, error: failure);
    } else {
      state = state.copyWith(isLoading: false, verifySucceeded: true);
    }

    return failure;
  }

  Future<void> resend({
    required String email,
    required bool isRecovery,
  }) async {
    if (state.cooldownSeconds > 0) return;

    state = state.copyWith(isLoading: true, cooldownSeconds: 60, clearError: true);
    _startCooldown();

    final failure = await ref.read(resendCodeUseCaseProvider).call(
          email: email,
          isRecovery: isRecovery,
        );

    if (failure != null) {
      state = state.copyWith(isLoading: false, error: failure);
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.cooldownSeconds <= 1) {
        timer.cancel();
        state = state.copyWith(cooldownSeconds: 0);
      } else {
        state = state.copyWith(cooldownSeconds: state.cooldownSeconds - 1);
      }
    });
  }

  void clear() {
    _cooldownTimer?.cancel();
    state = const OtpState();
  }
}
