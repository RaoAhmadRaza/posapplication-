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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) return;
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

    setState(() => _errorMessage = next.error.toString());
    ref.read(signInControllerProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(signInControllerProvider, _onStateChange);
    final isLoading = ref.watch(signInControllerProvider).isLoading;

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
            label: 'Log in',
            loading: isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Forgot password?',
            variant: AppButtonVariant.plain,
            onPressed: () => context.go('/forgot'),
          ),
        ],
      ),
    );
  }
}
