import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../data/repositories/staff_repository_impl.dart';
import '../../domain/entities/staff_entities.dart';

class JoinRedeemPage extends ConsumerStatefulWidget {
  const JoinRedeemPage({super.key, required this.token, required this.validation});

  final String token;
  final InviteValidation validation;

  @override
  ConsumerState<JoinRedeemPage> createState() => _JoinRedeemPageState();
}

class _JoinRedeemPageState extends ConsumerState<JoinRedeemPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  bool get _emailLocked => widget.validation.emailLocked;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.validation.fullName ?? '';
    _emailCtrl.text = widget.validation.email ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailLocked
        ? (widget.validation.email ?? '')
        : _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email and password are required.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final (pendingEmail, failure) =
        await ref.read(staffRepositoryProvider).redeemInvite(
              email: email,
              password: password,
              token: widget.token,
              fullName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
            );
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _saving = false;
        _error = failure.message;
      });
      return;
    }
    // Confirm-email ON: a confirmation code was sent — finish via the OTP flow.
    if (pendingEmail != null) {
      context.go('/otp', extra: {'email': pendingEmail, 'isRecovery': false});
    } else {
      // Session already active (confirmation off) — let the redirect route in.
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.validation;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Join team', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('You are joining', style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 2),
                  Text(v.businessName ?? 'a business', style: AppTypography.headline),
                  const SizedBox(height: 4),
                  Text('as ${v.roleName ?? 'staff'}',
                      style: AppTypography.body.copyWith(color: AppColors.accent)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _nameCtrl,
              label: 'Your name',
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_emailLocked)
              _LockedField(label: 'Email (set by your invite)', value: widget.validation.email ?? '')
            else
              AppTextField(
                controller: _emailCtrl,
                label: 'Email',
                prefixIcon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
              ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _passwordCtrl,
              label: 'Choose a password',
              prefixIcon: Icons.lock_outline,
              obscure: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppInlineBanner(message: _error!, type: BannerType.error),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Create my login',
              fullWidth: true,
              loading: _saving,
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedField extends StatelessWidget {
  const _LockedField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.lock_outline, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Expanded(child: Text(value, style: AppTypography.body)),
          ],
        ),
      ],
    );
  }
}
