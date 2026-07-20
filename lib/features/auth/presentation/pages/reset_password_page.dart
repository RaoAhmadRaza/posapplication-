import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/auth_hero_scaffold.dart';
import '../../../../core/error/auth_failure.dart';
import '../controllers/reset_controller.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _errorMessage;
  String? _confirmError;
  bool _submitted = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _errorMessage = null;
      _confirmError = null;
    });

    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter a new password.');
      return;
    }

    if (password.length < 8) {
      setState(() => _errorMessage = 'Password must be at least 8 characters.');
      return;
    }

    if (password != confirm) {
      setState(() => _confirmError = 'Passwords do not match.');
      return;
    }

    _submitted = true;

    final failure = await ref
        .read(resetControllerProvider.notifier)
        .setNewPassword(password);

    if (!mounted) return;
    _submitted = false;

    if (failure != null) {
      setState(() => _errorMessage = failure.message);
    }
  }

  void _onStateChange(AsyncValue<void>? prev, AsyncValue<void> next) {
    if (next.hasError && mounted) {
      final msg = next.error is AuthFailure
          ? (next.error as AuthFailure).message
          : next.error.toString();
      setState(() => _errorMessage = msg);
      ref.read(resetControllerProvider.notifier).clear();
    }
  }

  Future<void> _restartForgot() async {
    RecoveryState.instance.reset();
    context.go('/forgot');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(resetControllerProvider, _onStateChange);
    final isLoading = ref.watch(resetControllerProvider).isLoading;
    final disabled = isLoading || _submitted;
    final isExpired = _errorMessage != null &&
        _errorMessage!.contains('reset session expired');

    return AuthHeroScaffold(
      child: AuthFormCard(
        title: 'Set a new password',
        subtitle: 'Choose a strong password for your account.',
        children: [
          if (_errorMessage != null) ...[
            AppInlineBanner(message: _errorMessage!),
            const SizedBox(height: AppSpacing.base),
          ],
          if (isExpired) ...[
            AppButton(
              label: 'Start over',
              variant: AppButtonVariant.plain,
              onPressed: _restartForgot,
              fullWidth: true,
            ),
            const SizedBox(height: AppSpacing.base),
          ],
          AppTextField(
            controller: _passwordController,
            label: 'New password',
            hint: 'At least 8 characters',
            obscure: true,
            textInputAction: TextInputAction.next,
            prefixIcon: Icons.lock_outline,
          ),
          const SizedBox(height: AppSpacing.fieldGap),
          AppTextField(
            controller: _confirmController,
            label: 'Confirm password',
            hint: 'Re-enter new password',
            obscure: true,
            textInputAction: TextInputAction.done,
            prefixIcon: Icons.lock_outline,
            errorText: _confirmError,
            onSubmitted: (_) => disabled ? null : _submit(),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: 'Update password',
            loading: isLoading,
            onPressed: disabled ? null : _submit,
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}
