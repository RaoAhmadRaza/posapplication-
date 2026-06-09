import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/responsive_form_scaffold.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    await ref.read(forgotControllerProvider.notifier).requestReset(email);
    if (mounted) {
      context.go('/otp', extra: {
        'email': email,
        'isRecovery': true,
      });
    }
  }

  void _onStateChange(AsyncValue<void>? prev, AsyncValue<void> next) {
    if (next.hasError && mounted) {
      setState(() => _errorMessage = next.error.toString());
      ref.read(forgotControllerProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(forgotControllerProvider, _onStateChange);
    final isLoading = ref.watch(forgotControllerProvider).isLoading;

    return ResponsiveFormScaffold(
      title: 'Reset password',
      subtitle: "Enter your email and we'll send you a recovery code.",
      footer: AppButton(
        label: 'Back to log in',
        variant: AppButtonVariant.plain,
        onPressed: () => context.go('/login'),
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
            textInputAction: TextInputAction.done,
            prefixIcon: Icons.email_outlined,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: 'Send code',
            loading: isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
