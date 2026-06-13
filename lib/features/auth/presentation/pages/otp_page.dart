import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_otp_field.dart';
import '../../../../core/design/widgets/responsive_form_scaffold.dart';
import '../../../../core/error/auth_failure.dart';
import '../controllers/otp_controller.dart';

class OtpPage extends ConsumerStatefulWidget {
  final String email;
  final bool isRecovery;

  const OtpPage({super.key, required this.email, required this.isRecovery});

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  String _code = '';
  bool _autoSubmitted = false;
  String? _errorMessage;
  String? _successMessage;

  void _onOtpChanged(String code) {
    _code = code;
    _autoSubmitted = false;
    setState(() => _errorMessage = null);
  }

  void _onOtpCompleted(String code) {
    _code = code;
    if (!_autoSubmitted) {
      _autoSubmitted = true;
      _verify();
    }
  }

  Future<void> _verify() async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    if (_code.isEmpty || _code.length < 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit code.');
      _autoSubmitted = false;
      return;
    }

    await ref.read(otpControllerProvider.notifier).verify(
          email: widget.email,
          code: _code,
          isRecovery: widget.isRecovery,
        );
  }

  Future<void> _resend() async {
    _autoSubmitted = false;
    _code = '';
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });
    await ref.read(otpControllerProvider.notifier).resend(
          email: widget.email,
          isRecovery: widget.isRecovery,
        );
  }

  void _back() {
    RecoveryState.instance.reset();
    context.go('/login');
  }

  void _onStateChange(OtpState? prev, OtpState next) {
    if (!mounted) return;

    if (next.error != null) {
      _autoSubmitted = false;
      setState(() {
        _errorMessage = next.error!.message;
        _successMessage = null;
      });
    }

    if (next.resendSucceeded) {
      setState(() {
        _successMessage = 'A new code has been sent to $_maskedEmail.';
        _errorMessage = null;
      });
    }
  }

  String get _maskedEmail {
    final parts = widget.email.split('@');
    if (parts.length != 2) return widget.email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '${name[0]}***@$domain';
    return '${name[0]}${'*' * (name.length - 2)}${name[name.length - 1]}@$domain';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(otpControllerProvider, _onStateChange);
    final otpState = ref.watch(otpControllerProvider);
    final disabled = otpState.isLoading || otpState.verifySucceeded;

    return ResponsiveFormScaffold(
      title: 'Check your email',
      subtitle: 'We sent a code to $_maskedEmail',
      footer: AppButton(
        label: 'Back',
        variant: AppButtonVariant.plain,
        onPressed: widget.isRecovery ? _back : () => context.go('/login'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_successMessage != null) ...[
            AppInlineBanner(message: _successMessage!, type: BannerType.success),
            const SizedBox(height: AppSpacing.base),
          ],
          if (_errorMessage != null) ...[
            AppInlineBanner(message: _errorMessage!),
            const SizedBox(height: AppSpacing.base),
          ],
          const SizedBox(height: AppSpacing.sm),
          AppOtpField(
            length: 6,
            onChanged: _onOtpChanged,
            onCompleted: _onOtpCompleted,
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: 'Verify',
            loading: otpState.isLoading,
            onPressed: disabled ? null : _verify,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: otpState.cooldownSeconds > 0
                ? 'Resend code (${otpState.cooldownSeconds}s)'
                : 'Resend code',
            variant: AppButtonVariant.plain,
            onPressed: otpState.cooldownSeconds > 0 || otpState.isLoading
                ? null
                : _resend,
          ),
        ],
      ),
    );
  }
}
