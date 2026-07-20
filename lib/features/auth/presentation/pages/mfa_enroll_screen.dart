import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_otp_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/design/widgets/auth_hero_scaffold.dart';
import '../../domain/usecases/challenge_mfa.dart';
import '../../domain/usecases/enroll_mfa.dart';
import '../../domain/usecases/verify_mfa.dart';

class MfaEnrollScreen extends ConsumerStatefulWidget {
  const MfaEnrollScreen({super.key});

  @override
  ConsumerState<MfaEnrollScreen> createState() => _MfaEnrollScreenState();
}

class _MfaEnrollScreenState extends ConsumerState<MfaEnrollScreen> {
  final _codeController = TextEditingController();
  String? _factorId;
  String? _qrCodeUri;
  String? _secret;
  String? _challengeId;
  String? _errorMessage;
  bool _loading = true;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _enroll();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _enroll() async {
    final (result, enrollFailure) =
        await ref.read(enrollMfaUseCaseProvider).call();
    if (!mounted) return;
    if (enrollFailure != null || result == null) {
      setState(() {
        _errorMessage =
            enrollFailure?.message ?? 'Failed to set up authenticator.';
        _loading = false;
      });
      return;
    }
    final (challengeId, challengeFailure) =
        await ref.read(challengeMfaUseCaseProvider).call(result.factorId);
    if (!mounted) return;
    if (challengeFailure != null || challengeId == null) {
      setState(() {
        _errorMessage =
            challengeFailure?.message ?? 'Failed to set up authenticator.';
        _loading = false;
      });
      return;
    }
    setState(() {
      _factorId = result.factorId;
      _qrCodeUri = result.qrCodeUri;
      _secret = result.secret;
      _challengeId = challengeId;
      _loading = false;
    });
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit code.');
      return;
    }

    if (_factorId == null || _challengeId == null) return;

    setState(() {
      _verifying = true;
      _errorMessage = null;
    });

    final failure = await ref.read(verifyMfaUseCaseProvider).call(
          factorId: _factorId!,
          challengeId: _challengeId!,
          code: code,
        );

    if (!mounted) return;

    if (failure == null) {
      if (context.mounted) {
        showAppToast(context, 'Two-factor enabled', type: BannerType.success);
      }
      Navigator.of(context).pop();
    } else {
      // Typed failure: InvalidOtpFailure → wrong code; MfaTransientFailure →
      // connection problem. Surface the real message, never a blanket "wrong".
      setState(() {
        _verifying = false;
        _errorMessage = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return AuthHeroScaffold(
      child: AuthFormCard(
        title: 'Set up authenticator',
        subtitle: 'Scan the QR with your authenticator app to secure sign-in.',
        footer: AppButton(
          label: 'Back',
          variant: AppButtonVariant.plain,
          onPressed: () => Navigator.of(context).pop(),
          fullWidth: true,
        ),
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (_errorMessage != null) ...[
              AppInlineBanner(message: _errorMessage!),
              const SizedBox(height: AppSpacing.base),
            ],
            if (_qrCodeUri != null) ...[
              Center(
                // QR stays on a fixed white surface for scannability in dark mode.
                child: ClayContainer(
                  variant: ClayVariant.inset,
                  color: Colors.white,
                  borderRadius: AppRadius.lg,
                  padding: const EdgeInsets.all(AppSpacing.base),
                  child: QrImageView(
                    data: _qrCodeUri!,
                    version: QrVersions.auto,
                    size: 200,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Or enter this secret:',
                textAlign: TextAlign.center,
                style: AppTypography.footnote.copyWith(color: lum.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              ClayContainer(
                variant: ClayVariant.inset,
                color: lum.surface2,
                borderRadius: AppRadius.md,
                isDark: lum.isDark,
                padding: const EdgeInsets.only(
                  top: AppSpacing.md,
                  bottom: AppSpacing.md,
                  left: AppSpacing.base,
                  right: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatSecret(_secret ?? ''),
                        textAlign: TextAlign.center,
                        style: AppTypography.monoValue.copyWith(
                          fontSize: 18,
                          letterSpacing: 2,
                          color: lum.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded),
                      iconSize: 20,
                      color: lum.textSecondary,
                      tooltip: 'Copy secret',
                      onPressed: _copySecret,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Enter the 6-digit code from your authenticator app to verify.',
                style: AppTypography.subhead.copyWith(color: lum.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              AppOtpField(
                controller: _codeController,
                onCompleted: (_) => _verifying ? null : _verify(),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Verify',
                loading: _verifying,
                onPressed: _verifying ? null : _verify,
                fullWidth: true,
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _copySecret() {
    final raw = (_secret ?? '').replaceAll(' ', '');
    if (raw.isEmpty) return;
    Clipboard.setData(ClipboardData(text: raw));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Secret copied')),
    );
  }

  String _formatSecret(String secret) {
    final buffer = StringBuffer();
    for (int i = 0; i < secret.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(secret[i]);
    }
    return buffer.toString();
  }
}
