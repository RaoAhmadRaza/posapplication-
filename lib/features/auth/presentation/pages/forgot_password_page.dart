import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/auth_hero_scaffold.dart';
import '../../../../core/error/auth_failure.dart';
import '../controllers/forgot_controller.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() =>
      _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  String? _errorMessage;
  bool _submitted = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool get _isValidEmail {
    final email = _emailController.text.trim();
    if (email.isEmpty) return false;
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(email);
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);

    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address.');
      return;
    }

    if (!_isValidEmail) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }

    _submitted = true;

    final failure = await ref
        .read(forgotControllerProvider.notifier)
        .requestReset(email);

    if (!mounted) return;
    _submitted = false;

    if (failure != null) {
      setState(() => _errorMessage = failure.message);
      return;
    }

    RecoveryState.instance.stage = RecoveryStage.awaitingCode;
    if (mounted) {
      context.go('/otp', extra: {
        'email': email,
        'isRecovery': true,
      });
    }
  }

  void _onStateChange(AsyncValue<void>? prev, AsyncValue<void> next) {
    if (next.hasError && mounted) {
      final msg = next.error is AuthFailure
          ? (next.error as AuthFailure).message
          : 'Unable to complete the request. Please try again.';
      setState(() => _errorMessage = msg);
      ref.read(forgotControllerProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(forgotControllerProvider, _onStateChange);
    final isLoading = ref.watch(forgotControllerProvider).isLoading;
    final disabled = isLoading || _submitted;

    return AuthHeroScaffold(
      child: AuthFormCard(
        title: 'Reset password',
        subtitle:
            "Enter your email. If an account exists, we'll send a recovery code.",
        footer: AppButton(
          label: 'Back to log in',
          variant: AppButtonVariant.plain,
          onPressed: () => context.go('/login'),
          fullWidth: true,
        ),
        children: [
          if (_errorMessage != null) ...[
            AppInlineBanner(message: _errorMessage!),
            const SizedBox(height: AppSpacing.base),
          ],
          AppTextField(
            controller: _emailController,
            label: 'Email',
            hint: 'you@company.com',
            autofocus: true,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            prefixIcon: Icons.mail_outline,
            onSubmitted: (_) => disabled ? null : _submit(),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: 'Send code',
            loading: isLoading,
            onPressed: disabled ? null : _submit,
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}
