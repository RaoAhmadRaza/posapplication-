import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_checkbox.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/auth_hero_scaffold.dart';
import '../../../../core/error/auth_failure.dart';
import '../../../../core/services/login_throttle_service.dart';
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
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  String? _cooldownEmail;
  bool _remember = true; // decorative — Supabase persists the session by default

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Email and password are required.');
      return;
    }

    final (canAttempt, remaining) =
        await LoginThrottleService.instance.canAttempt(email);
    if (!canAttempt) {
      setState(() => _errorMessage =
          'Too many attempts. Try again in ${_formatSeconds(remaining)}.');
      _startCooldownCheck(email);
      return;
    }

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

    if (next.error is AccountLockedFailure) {
      final failure = next.error as AccountLockedFailure;
      setState(() => _errorMessage = failure.message);
      _startCooldownCheck(_emailController.text.trim());
      ref.read(signInControllerProvider.notifier).clear();
      return;
    }

    final msg = next.error is AuthFailure
        ? (next.error as AuthFailure).message
        : next.error.toString();

    if (next.error is InvalidCredentialsFailure) {
      _startCooldownCheck(_emailController.text.trim());
    }

    setState(() => _errorMessage = msg);
    ref.read(signInControllerProvider.notifier).clear();
  }

  void _startCooldownCheck(String email) {
    _cooldownEmail = email;
    _cooldownTimer?.cancel();
    _tick();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _tick() async {
    // Use the email captured when the cooldown started, not the live field —
    // editing the email box mid-cooldown must not cancel the lockout.
    final email = _cooldownEmail;
    if (email == null || email.isEmpty) {
      if (mounted) setState(() => _cooldownSeconds = 0);
      return;
    }
    final (canAttempt, remaining) =
        await LoginThrottleService.instance.canAttempt(email);
    if (!mounted) return;
    setState(() => _cooldownSeconds = canAttempt ? 0 : remaining);
    if (canAttempt) _cooldownTimer?.cancel();
  }

  String _formatSeconds(int s) {
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m}m ${sec}s';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(signInControllerProvider, _onStateChange);
    final isLoading = ref.watch(signInControllerProvider).isLoading;
    final disabled = isLoading || _cooldownSeconds > 0;
    final lum = context.lum;

    return AuthHeroScaffold(
      child: ClayContainer(
        variant: ClayVariant.raised,
        color: lum.surface,
        borderRadius: AppRadius.xl,
        isDark: lum.isDark,
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Welcome back',
              style: AppTypography.largeTitle.copyWith(color: lum.textPrimary),
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null) ...[
              AppInlineBanner(message: _errorMessage!),
              const SizedBox(height: 16),
            ],
            AppTextField(
              controller: _emailController,
              label: 'Email',
              hint: 'you@company.com',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.mail_outline,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _passwordController,
              label: 'Password',
              hint: 'Your password',
              obscure: true,
              textInputAction: TextInputAction.done,
              prefixIcon: Icons.lock_outline,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: AppCheckbox(
                value: _remember,
                onChanged: (v) => setState(() => _remember = v),
                label: 'Remember me',
              ),
            ),
            const SizedBox(height: 20),
            AppButton(
              label: _cooldownSeconds > 0
                  ? 'Try again in ${_formatSeconds(_cooldownSeconds)}'
                  : 'Sign in',
              loading: isLoading,
              onPressed: disabled ? null : _submit,
              fullWidth: true,
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Use PIN instead',
              variant: AppButtonVariant.plain,
              onPressed: () => context.go('/pin-lock'),
              fullWidth: true,
            ),
            Center(
              child: TextButton(
                onPressed: () => context.go('/forgot'),
                child: Text(
                  'Forgot password?',
                  style: AppTypography.footnote
                      .copyWith(color: lum.textTertiary),
                ),
              ),
            ),
            const SizedBox(height: 6),
            _QrJoinButton(onTap: () => context.push('/join/scan')),
            const SizedBox(height: 18),
            Divider(color: lum.hairline, height: 1),
            const SizedBox(height: 16),
            Center(
              child: Text.rich(
                TextSpan(
                  text: 'New to LUMINA? ',
                  style: AppTypography.footnote
                      .copyWith(color: lum.textSecondary, fontSize: 14),
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: GestureDetector(
                        onTap: () => context.go('/signup'),
                        child: Text(
                          'Create an account',
                          style: AppTypography.label.copyWith(
                            color: lum.accent,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashed "scan invite QR" affordance from the mock.
class _QrJoinButton extends StatelessWidget {
  const _QrJoinButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return GestureDetector(
      onTap: onTap,
      child: DottedBorderBox(
        color: lum.g300,
        radius: AppRadius.md,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_2, size: 18, color: lum.accent),
              const SizedBox(width: 9),
              Text(
                'Joining a team? Scan your invite QR',
                style: AppTypography.label.copyWith(color: lum.g700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Minimal dashed-border wrapper (Flutter has no native dashed border).
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({
    super.key,
    required this.child,
    required this.color,
    this.radius = 12,
  });

  final Widget child;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedPainter(color: color, radius: radius),
      child: child,
    );
  }
}

class _DashedPainter extends CustomPainter {
  _DashedPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, d + dash),
          paint,
        );
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) =>
      old.color != color || old.radius != radius;
}
