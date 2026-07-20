import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/responsive_form_scaffold.dart';
import '../../../../core/error/auth_failure.dart';
import '../../../../core/services/login_throttle_service.dart';
import '../controllers/sign_in_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  String? _cooldownEmail;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Email and password are required.');
      return;
    }

    final (canAttempt, remaining) = await LoginThrottleService.instance.canAttempt(email);
    if (!canAttempt) {
      setState(() => _errorMessage = 'Too many attempts. Try again in ${_formatSeconds(remaining)}.');
      _startCooldownCheck(email);
      return;
    }

    await ref.read(signInControllerProvider.notifier).signIn(email, password);
  }

  void _onStateChange(AsyncValue<void>? prev, AsyncValue<void> next) {
    if (!next.hasError || !mounted) return;

    if (next.error is EmailNotConfirmedFailure) {
      final failure = next.error as EmailNotConfirmedFailure;
      ref.read(signInControllerProvider.notifier).clear();
      context.go('/otp', extra: {
        'email': failure.email,
        'isRecovery': false,
      });
      return;
    }

    if (next.error is AccountLockedFailure) {
      final failure = next.error as AccountLockedFailure;
      setState(() => _errorMessage = failure.message);
      _startCooldownCheck(_emailController.text.trim());
      ref.read(signInControllerProvider.notifier).clear();
      return;
    }

    final msg = next.error is AuthFailure
        ? (next.error as AuthFailure).message
        : next.error.toString();

    if (next.error is InvalidCredentialsFailure) {
      _startCooldownCheck(_emailController.text.trim());
    }

    setState(() => _errorMessage = msg);
    ref.read(signInControllerProvider.notifier).clear();
  }

  void _startCooldownCheck(String email) {
    _cooldownEmail = email;
    _cooldownTimer?.cancel();
    _tick();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _tick() async {
    // Use the email captured when the cooldown started, not the live field —
    // editing the email box mid-cooldown must not cancel the lockout.
    final email = _cooldownEmail;
    if (email == null || email.isEmpty) {
      if (mounted) setState(() => _cooldownSeconds = 0);
      return;
    }
    final (canAttempt, remaining) = await LoginThrottleService.instance.canAttempt(email);
    if (!mounted) return;
    setState(() => _cooldownSeconds = canAttempt ? 0 : remaining);
    if (canAttempt) _cooldownTimer?.cancel();
  }

  String _formatSeconds(int s) {
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m}m ${sec}s';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(signInControllerProvider, _onStateChange);
    final isLoading = ref.watch(signInControllerProvider).isLoading;
    final disabled = isLoading || _cooldownSeconds > 0;

    return ResponsiveFormScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to your account',
      footer: Column(
        children: [
          Text(
            "Don't have an account?",
            style: AppTypography.footnote.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Create account',
            variant: AppButtonVariant.tinted,
            onPressed: () => context.go('/signup'),
            fullWidth: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Joining a team? Scan your invite QR',
            variant: AppButtonVariant.plain,
            onPressed: () => context.push('/join/scan'),
            fullWidth: true,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            AppInlineBanner(message: _errorMessage!),
            const SizedBox(height: AppSpacing.base),
          ],
          AppTextField(
            controller: _emailController,
            label: 'Email',
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            prefixIcon: Icons.email_outlined,
          ),
          const SizedBox(height: AppSpacing.fieldGap),
          AppTextField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Enter your password',
            obscure: true,
            textInputAction: TextInputAction.done,
            prefixIcon: Icons.lock_outline,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: _cooldownSeconds > 0
                ? 'Try again in ${_formatSeconds(_cooldownSeconds)}'
                : 'Log in',
            loading: isLoading,
            onPressed: disabled ? null : _submit,
            fullWidth: true,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Forgot password?',
            variant: AppButtonVariant.plain,
            onPressed: () => context.go('/forgot'),
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}
