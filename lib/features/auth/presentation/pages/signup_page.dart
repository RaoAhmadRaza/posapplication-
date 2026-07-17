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
import '../../domain/repositories/auth_repository.dart';
import '../controllers/sign_up_controller.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _businessNameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _businessNameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    final businessName = _businessNameController.text.trim();
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Email and password are required.');
      return;
    }
    // Business name is required: a blank one used to drop the user into the shared
    // Demo Store. Joining a real team goes through the invite QR, not this form.
    if (businessName.isEmpty) {
      setState(() => _errorMessage =
          'Business name is required. Joining an existing team? Use "Scan invite QR" on the login screen.');
      return;
    }

    final needsConfirmationEmail =
        await ref.read(signUpControllerProvider.notifier).signUp(
              email: email,
              password: password,
              fullName: fullName.isNotEmpty ? fullName : null,
              businessName: businessName,
            );
    _afterSignUp(needsConfirmationEmail);
  }

  Future<void> _submitDemo() async {
    setState(() => _errorMessage = null);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Enter an email and password to try the demo.');
      return;
    }
    final fullName = _fullNameController.text.trim();
    final needsConfirmationEmail =
        await ref.read(signUpControllerProvider.notifier).signUp(
              email: email,
              password: password,
              fullName: fullName.isNotEmpty ? fullName : null,
              demoMode: true,
            );
    _afterSignUp(needsConfirmationEmail);
  }

  void _afterSignUp(String? needsConfirmationEmail) {
    if (needsConfirmationEmail != null && mounted) {
      context.go('/otp', extra: {
        'email': needsConfirmationEmail,
        'isRecovery': false,
      });
    }
  }

  void _onStateChange(
      AsyncValue<SignUpResult>? prev, AsyncValue<SignUpResult> next) {
    if (next.hasError && mounted) {
      setState(() => _errorMessage = next.error.toString());
      ref.read(signUpControllerProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(signUpControllerProvider, _onStateChange);
    final isLoading = ref.watch(signUpControllerProvider).isLoading;

    return ResponsiveFormScaffold(
      title: 'Create your account',
      subtitle: 'Get started with your store',
      footer: Column(
        children: [
          Text(
            'Already have an account?',
            style: AppTypography.footnote.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Log in',
            variant: AppButtonVariant.tinted,
            onPressed: () => context.go('/login'),
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
            controller: _businessNameController,
            label: 'Business name',
            hint: 'Your store name',
            textInputAction: TextInputAction.next,
            prefixIcon: Icons.store_outlined,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Required — this creates your store. Joining a team? Use "Scan invite QR" on the login screen.',
              style: AppTypography.caption.copyWith(
                color: AppColors.textHint,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.fieldGap),
          AppTextField(
            controller: _fullNameController,
            label: 'Full name',
            hint: 'Your full name',
            textInputAction: TextInputAction.next,
            prefixIcon: Icons.person_outline,
          ),
          const SizedBox(height: AppSpacing.fieldGap),
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
            hint: 'Create a password',
            obscure: true,
            textInputAction: TextInputAction.done,
            prefixIcon: Icons.lock_outline,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.xs),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _passwordController,
            builder: (context, value, _) {
              return _PasswordStrengthHint(password: value.text);
            },
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: 'Create account',
            loading: isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Try the demo instead',
            variant: AppButtonVariant.plain,
            onPressed: isLoading ? null : _submitDemo,
          ),
        ],
      ),
    );
  }
}

class _PasswordStrengthHint extends StatelessWidget {
  const _PasswordStrengthHint({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    String label;
    Color color;
    double fraction;

    if (password.length < 6) {
      label = 'Weak';
      color = AppColors.destructive;
      fraction = 0.33;
    } else if (password.length < 8) {
      label = 'Medium';
      color = AppColors.warning;
      fraction = 0.66;
    } else {
      label = 'Strong';
      color = AppColors.success;
      fraction = 1.0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: fraction,
            backgroundColor: AppColors.fieldFill,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.caption.copyWith(color: color),
        ),
      ],
    );
  }
}
