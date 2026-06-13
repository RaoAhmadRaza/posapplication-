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
  final bool resendSucceeded;

  const OtpState({
    this.isLoading = false,
    this.verifySucceeded = false,
    this.error,
    this.cooldownSeconds = 0,
    this.resendSucceeded = false,
  });

  OtpState copyWith({
    bool? isLoading,
    bool? verifySucceeded,
    AuthFailure? error,
    int? cooldownSeconds,
    bool? resendSucceeded,
    bool clearError = false,
    bool clearResend = false,
  }) {
    return OtpState(
      isLoading: isLoading ?? this.isLoading,
      verifySucceeded: verifySucceeded ?? this.verifySucceeded,
      error: clearError ? null : error,
      cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
      resendSucceeded: clearResend ? false : (resendSucceeded ?? this.resendSucceeded),
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
    state = state.copyWith(isLoading: true, clearError: true, clearResend: true);
    AuthFailure? failure;

    if (isRecovery) {
      failure = await ref.read(verifyRecoveryOtpUseCaseProvider).call(
            email: email,
            code: code,
          );
    } else {
      failure = await ref.read(verifyEmailOtpUseCaseProvider).call(
            email: email,
            code: code,
          );
    }

    if (failure != null) {
      state = state.copyWith(isLoading: false, error: failure);
    } else {
      if (isRecovery) {
        RecoveryState.instance.stage = RecoveryStage.codeVerified;
      }
      state = state.copyWith(isLoading: false, verifySucceeded: true);
    }

    return failure;
  }

  Future<void> resend({
    required String email,
    required bool isRecovery,
  }) async {
    if (state.cooldownSeconds > 0 || state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true, clearResend: true);

    final failure = await ref.read(resendCodeUseCaseProvider).call(
          email: email,
          isRecovery: isRecovery,
        );

    if (failure != null) {
      state = state.copyWith(isLoading: false, error: failure);
    } else {
      state = state.copyWith(
        isLoading: false,
        cooldownSeconds: 60,
        resendSucceeded: true,
      );
      _startCooldown();
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
