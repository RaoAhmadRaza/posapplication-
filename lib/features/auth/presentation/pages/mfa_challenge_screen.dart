import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_otp_field.dart';
import '../../../../core/design/widgets/responsive_form_scaffold.dart';
import '../../../../core/state/app_flow_state.dart';
import '../../domain/usecases/challenge_mfa.dart';
import '../../domain/usecases/get_enrolled_factor_id.dart';
import '../../domain/usecases/verify_mfa.dart';

class MfaChallengeScreen extends ConsumerStatefulWidget {
  const MfaChallengeScreen({super.key});

  @override
  ConsumerState<MfaChallengeScreen> createState() => _MfaChallengeScreenState();
}

class _MfaChallengeScreenState extends ConsumerState<MfaChallengeScreen> {
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
            challengeFailure?.message ?? 'Could not start authentication.';
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveFormScaffold(
      title: 'Two-factor authentication',
      subtitle: 'Enter the code from your authenticator app.',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) ...[
                  AppInlineBanner(message: _errorMessage!),
                  const SizedBox(height: AppSpacing.base),
                ],
                const SizedBox(height: AppSpacing.md),
                AppOtpField(
                  length: 6,
                  onCompleted: _verifying ? (_) {} : _verify,
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Use another method',
                  variant: AppButtonVariant.plain,
                  onPressed: () {
                    MfaState.instance.clear();
                  },
                ),
              ],
            ),
    );
  }
}
