import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/responsive_form_scaffold.dart';
import '../../../../core/services/pin_service.dart';
import '../../../../core/state/app_flow_state.dart';
import '../../../../core/supabase.dart';
import '../../../../core/widgets/pin_pad.dart';

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  static const _maxAttempts = 3;

  final _localAuth = LocalAuthentication();
  String? _errorMessage;
  int _attempts = 0;
  bool _verifying = false;
  bool _showBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    final enabled = await PinService.instance.isBiometricsEnabled();
    if (mounted) {
      setState(() {
        _showBiometrics = canCheck && enabled;
      });
    }
  }

  Future<void> _biometricUnlock() async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Unlock Lumina POS',
      );
      if (!mounted) return;
      if (ok) {
        PinLockState.instance.unlock();
      }
    } on PlatformException catch (e) {
      // Surface native failures instead of swallowing them — e.g. a
      // misconfigured Activity, no enrolled biometric, or a locked-out sensor.
      // The user can still fall back to the PIN pad below.
      if (!mounted) return;
      setState(() => _errorMessage =
          e.message ?? 'Biometric unlock unavailable. Enter your PIN.');
    }
  }

  Future<void> _onComplete(String pin) async {
    setState(() {
      _verifying = true;
      _errorMessage = null;
    });

    final ok = await PinService.instance.verifyPin(pin);

    if (!mounted) return;

    if (ok) {
      _attempts = 0;
      PinLockState.instance.unlock();
    } else {
      _attempts++;
      if (_attempts >= _maxAttempts) {
        HapticFeedback.heavyImpact();
        await _lockOut();
        return;
      }
      setState(() {
        _verifying = false;
        _errorMessage =
            'Incorrect PIN. ${_maxAttempts - _attempts} attempts remaining.';
      });
    }
  }

  /// Too many wrong PINs. A wrong PIN must NEVER grant app access — sign the
  /// user out and force a full re-login (email + password). We do NOT call
  /// PinLockState.unlock(): that would drop the guesser straight into the
  /// dashboard on the victim's live session (brute-force bypass).
  Future<void> _lockOut() async {
    setState(() {
      _verifying = true;
      _errorMessage = null;
    });
    try {
      // SIGNED_OUT fires -> router resetUserScopedState() clears the lock and
      // the redirect sends the now-logged-out user to /login. signOut() clears
      // the local session even if the server revoke can't be reached.
      await supabase.auth.signOut();
    } on Object catch (_) {
      // Never fall through to access. Keep the screen locked and let the user
      // retry the sign-out rather than reaching the app.
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _attempts = 0;
        _errorMessage = 'Too many attempts. Please sign in again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveFormScaffold(
      title: 'Enter PIN',
      subtitle: 'Use your PIN to unlock.',
      child: _verifying
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) ...[
                  AppInlineBanner(message: _errorMessage!),
                  const SizedBox(height: AppSpacing.base),
                ],
                if (_showBiometrics) ...[
                  _BiometricButton(onTap: _biometricUnlock),
                  const SizedBox(height: AppSpacing.xl),
                ],
                const SizedBox(height: AppSpacing.md),
                PinPad(
                  length: 4,
                  onCompleted: _verifying ? (_) {} : _onComplete,
                ),
              ],
            ),
    );
  }
}

class _BiometricButton extends StatelessWidget {
  const _BiometricButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: 'Use Face ID / fingerprint',
      variant: AppButtonVariant.tinted,
      icon: Icons.fingerprint,
      onPressed: onTap,
    );
  }
}
