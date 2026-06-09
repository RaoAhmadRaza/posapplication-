import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/responsive_form_scaffold.dart';
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

    if (password.isEmpty) return;

    if (password != confirm) {
      setState(() => _confirmError = 'Passwords do not match.');
      return;
    }

    await ref.read(resetControllerProvider.notifier).setNewPassword(password);
  }

  void _onStateChange(AsyncValue<void>? prev, AsyncValue<void> next) {
    if (next.hasError && mounted) {
      setState(() => _errorMessage = next.error.toString());
      ref.read(resetControllerProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(resetControllerProvider, _onStateChange);
    final isLoading = ref.watch(resetControllerProvider).isLoading;

    return ResponsiveFormScaffold(
      title: 'Set a new password',
      subtitle: 'Choose a strong password for your account.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            AppInlineBanner(message: _errorMessage!),
            const SizedBox(height: AppSpacing.base),
          ],
          AppTextField(
            controller: _passwordController,
            label: 'New password',
            hint: 'Enter new password',
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
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: 'Update password',
            loading: isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
