import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
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
    final email =
        _emailLocked ? (widget.validation.email ?? '') : _emailCtrl.text.trim();
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
    return AppDetailScaffold(
      eyebrow: 'Join',
      title: 'Create your login',
      maxContentWidth: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _JoinSummary(businessName: v.businessName, roleName: v.roleName),
          const SizedBox(height: 22),
          AppTextField(
            controller: _nameCtrl,
            label: 'Your name',
            prefixIcon: Icons.person_outline,
          ),
          const SizedBox(height: 16),
          if (_emailLocked)
            _LockedField(value: widget.validation.email ?? '')
          else
            AppTextField(
              controller: _emailCtrl,
              label: 'Email',
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
            ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _passwordCtrl,
            label: 'Choose a password',
            prefixIcon: Icons.lock_outline,
            obscure: true,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            AppInlineBanner(message: _error!, type: BannerType.error),
          ],
          const SizedBox(height: 24),
          AppButton(
            label: 'Create my login',
            fullWidth: true,
            loading: _saving,
            onPressed: _saving ? null : _submit,
          ),
        ],
      ),
    );
  }
}

/// The "you are joining {business} as {role}" clay summary at the top.
class _JoinSummary extends StatelessWidget {
  const _JoinSummary({this.businessName, this.roleName});
  final String? businessName;
  final String? roleName;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return ClayContainer(
      variant: ClayVariant.soft,
      color: lum.surface,
      borderRadius: AppRadius.lg,
      isDark: lum.isDark,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          ClayContainer(
            variant: ClayVariant.soft,
            color: lum.accentSoft,
            borderRadius: AppRadius.md,
            isDark: lum.isDark,
            width: 44,
            height: 44,
            child: Icon(LucideIcons.building2, size: 20, color: lum.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You are joining',
                    style: AppTypography.footnote.copyWith(color: lum.g500)),
                const SizedBox(height: 2),
                Text(businessName ?? 'a business',
                    style: AppTypography.headline
                        .copyWith(fontSize: 16, color: lum.textPrimary)),
                const SizedBox(height: 2),
                Text('as ${roleName ?? 'staff'}',
                    style: AppTypography.footnote.copyWith(color: lum.accentPress)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-only email field when the invite locked it to a specific address.
class _LockedField extends StatelessWidget {
  const _LockedField({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Email (set by your invite)',
            style: AppTypography.label.copyWith(color: lum.g700)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: lum.surface2,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.lock, size: 16, color: lum.g500),
              const SizedBox(width: 8),
              Expanded(
                child: Text(value,
                    style: AppTypography.body.copyWith(color: lum.textPrimary)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
