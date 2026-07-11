import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Set up authenticator', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          child: _loading
              ? const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      AppInlineBanner(message: _errorMessage!),
                      const SizedBox(height: AppSpacing.base),
                    ],
                    if (_qrCodeUri != null) ...[
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(color: AppColors.separator, width: 0.5),
                          ),
                          child: QrImageView(
                            data: _qrCodeUri!,
                            version: QrVersions.auto,
                            size: 200,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Center(
                        child: Text(
                          'Or enter this secret:',
                          style: AppTypography.footnote.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Center(
                        child: Text(
                          _formatSecret(_secret ?? ''),
                          style: AppTypography.headline.copyWith(letterSpacing: 2),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        'Enter the 6-digit code from your authenticator app to verify.',
                        style: AppTypography.subhead.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _codeController,
                        label: 'Verification code',
                        prefixIcon: Icons.lock_outline,
                        hint: '000000',
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _verifying ? null : _verify(),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      AppButton(
                        label: 'Verify',
                        loading: _verifying,
                        onPressed: _verifying ? null : _verify,
                      ),
                    ],
                  ],
                ),
        ),
      ),
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
