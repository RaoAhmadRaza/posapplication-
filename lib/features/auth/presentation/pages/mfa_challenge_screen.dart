import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_otp_field.dart';
import '../../../../core/design/widgets/auth_hero_scaffold.dart';
import '../../../../core/state/app_flow_state.dart';
import '../../../../core/supabase.dart';
import '../../domain/usecases/challenge_mfa.dart';
import '../../domain/usecases/get_enrolled_factor_id.dart';
import '../../domain/usecases/verify_mfa.dart';

class MfaChallengeScreen extends ConsumerStatefulWidget {
  const MfaChallengeScreen({super.key});

  @override
  ConsumerState<MfaChallengeScreen> createState() => _MfaChallengeScreenState();
}

class _MfaChallengeScreenState extends ConsumerState<MfaChallengeScreen> {
  final _otpController = TextEditingController();
  final _otpFocus = FocusNode();
  String? _factorId;
  String? _challengeId;
  String? _errorMessage;
  bool _loading = true;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _startChallenge();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  Future<void> _startChallenge() async {
    final (factorId, factorFailure) =
        await ref.read(getEnrolledFactorIdUseCaseProvider).call();
    if (!mounted) return;
    if (factorFailure != null) {
      setState(() {
        _errorMessage = factorFailure.message;
        _loading = false;
      });
      return;
    }
    if (factorId == null) {
      MfaState.instance.clear();
      return;
    }
    final (challengeId, challengeFailure) =
        await ref.read(challengeMfaUseCaseProvider).call(factorId);
    if (!mounted) return;
    if (challengeFailure != null || challengeId == null) {
      setState(() {
        _errorMessage =
            challengeFailure?.message ?? 'Unable to start authentication.';
        _loading = false;
      });
      return;
    }
    setState(() {
      _factorId = factorId;
      _challengeId = challengeId;
      _loading = false;
    });
  }

  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    await _startChallenge();
  }

  Future<void> _verify(String code) async {
    if (_factorId == null || _challengeId == null) return;

    setState(() {
      _verifying = true;
      _errorMessage = null;
    });

    final failure = await ref.read(verifyMfaUseCaseProvider).call(
          factorId: _factorId!,
          challengeId: _challengeId!,
          code: code,
        );

    if (!mounted) return;

    if (failure == null) {
      MfaState.instance.clear();
    } else {
      // InvalidOtpFailure → "Incorrect code…"; MfaTransientFailure → connection
      // banner. Either way surface the typed message and let the user retry.
      setState(() {
        _verifying = false;
        _errorMessage = failure.message;
      });
      // Wrong code: wipe the field and refocus so the next 6 digits re-submit.
      _otpController.clear();
      _otpFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthHeroScaffold(
      child: AuthFormCard(
        title: 'Two-factor authentication',
        subtitle: 'Enter the code from your authenticator app.',
        footer: _loading
            ? null
            : AppButton(
                // "Use another method" only cleared MFA state, which bounced
                // back through workspace-init and re-required MFA (infinite
                // loop). Signing out is the real escape — the router redirect
                // returns to /login.
                label: 'Sign out',
                variant: AppButtonVariant.plain,
                onPressed: () async {
                  await supabase.auth.signOut();
                },
                fullWidth: true,
              ),
        children: _loading
            ? const [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ]
            : _challengeId == null
                // Start failed: no challenge to answer. Offer a Retry instead
                // of an inert screen with a dead OTP field.
                ? [
                    if (_errorMessage != null) ...[
                      AppInlineBanner(message: _errorMessage!),
                      const SizedBox(height: AppSpacing.base),
                    ],
                    AppButton(
                      label: 'Retry',
                      onPressed: _retry,
                      fullWidth: true,
                    ),
                  ]
                : [
                    if (_errorMessage != null) ...[
                      AppInlineBanner(message: _errorMessage!),
                      const SizedBox(height: AppSpacing.base),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    AppOtpField(
                      length: 6,
                      controller: _otpController,
                      focusNode: _otpFocus,
                      onCompleted: _verifying ? (_) {} : _verify,
                    ),
                    if (_verifying) ...[
                      const SizedBox(height: AppSpacing.base),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ],
      ),
    );
  }
}
