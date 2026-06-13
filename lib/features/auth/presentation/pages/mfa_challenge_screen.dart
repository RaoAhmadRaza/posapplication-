import 'package:flutter/material.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_otp_field.dart';
import '../../../../core/design/widgets/responsive_form_scaffold.dart';
import '../../../../core/services/mfa_service.dart';
import '../../../../core/state/app_flow_state.dart';

class MfaChallengeScreen extends StatefulWidget {
  const MfaChallengeScreen({super.key});

  @override
  State<MfaChallengeScreen> createState() => _MfaChallengeScreenState();
}

class _MfaChallengeScreenState extends State<MfaChallengeScreen> {
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
    try {
      final factorId = await MfaService.instance.getEnrolledFactorId();
      if (factorId == null) {
        MfaState.instance.clear();
        return;
      }
      final challengeId = await MfaService.instance.challenge(factorId);
      if (mounted) {
        setState(() {
          _factorId = factorId;
          _challengeId = challengeId;
          _loading = false;
        });
      }
    } catch (_) {
      setState(() {
        _errorMessage = 'Could not start authentication.';
        _loading = false;
      });
    }
  }

  Future<void> _verify(String code) async {
    if (_factorId == null || _challengeId == null) return;

    setState(() {
      _verifying = true;
      _errorMessage = null;
    });

    final ok = await MfaService.instance.verify(
      factorId: _factorId!,
      challengeId: _challengeId!,
      code: code,
    );

    if (!mounted) return;

    if (ok) {
      MfaState.instance.clear();
    } else {
      setState(() {
        _verifying = false;
        _errorMessage = 'Incorrect code. Please try again.';
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
