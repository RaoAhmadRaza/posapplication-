import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/auth_hero_scaffold.dart';
import '../../../../core/services/pin_service.dart';
import '../../../../core/state/app_flow_state.dart';
import '../../../../core/supabase.dart';

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
    final lum = context.lum;

    return AuthHeroScaffold(
      child: ClayContainer(
        variant: ClayVariant.raised,
        color: lum.surface,
        borderRadius: AppRadius.xl,
        isDark: lum.isDark,
        padding: const EdgeInsets.all(28),
        child: _verifying
            ? SizedBox(
                height: 240,
                child: Center(
                  child: CircularProgressIndicator(color: lum.accent),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ClayContainer(
                      variant: ClayVariant.lumen,
                      color: lum.accent,
                      borderRadius: AppRadius.pill,
                      isDark: lum.isDark,
                      width: 64,
                      height: 64,
                      child: const Center(
                        child: Icon(Icons.lock_outline,
                            color: Colors.white, size: 26),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Enter PIN',
                    textAlign: TextAlign.center,
                    style: AppTypography.title2.copyWith(color: lum.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Use your PIN to unlock.',
                    textAlign: TextAlign.center,
                    style:
                        AppTypography.subhead.copyWith(color: lum.textSecondary),
                  ),
                  const SizedBox(height: 22),
                  if (_errorMessage != null) ...[
                    AppInlineBanner(message: _errorMessage!),
                    const SizedBox(height: 16),
                  ],
                  _ClayPinPad(length: 4, onCompleted: _onComplete),
                  if (_showBiometrics) ...[
                    const SizedBox(height: 22),
                    _BiometricButton(onTap: _biometricUnlock),
                  ],
                ],
              ),
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

/// Theme-aware clay PIN pad — mirrors the shared [PinPad] behaviour (auto-submit
/// on the last digit, haptics per keypress) but reads [LumColors] so dark mode
/// renders correctly and the keys use the LUMINA clay surface language.
class _ClayPinPad extends StatefulWidget {
  const _ClayPinPad({required this.length, required this.onCompleted});

  final int length;
  final ValueChanged<String> onCompleted;

  @override
  State<_ClayPinPad> createState() => _ClayPinPadState();
}

class _ClayPinPadState extends State<_ClayPinPad> {
  String _pin = '';

  void _add(String digit) {
    if (_pin.length >= widget.length) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += digit);
    if (_pin.length == widget.length) {
      widget.onCompleted(_pin);
    }
  }

  void _delete() {
    if (_pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DotRow(length: widget.length, filled: _pin.length, lum: lum),
        const SizedBox(height: 28),
        _KeyRow(keys: const ['1', '2', '3'], onTap: _add, lum: lum),
        _KeyRow(keys: const ['4', '5', '6'], onTap: _add, lum: lum),
        _KeyRow(keys: const ['7', '8', '9'], onTap: _add, lum: lum),
        _KeyRow(
          keys: const ['', '0', '<'],
          lum: lum,
          onTap: (v) {
            if (v.isEmpty) return;
            if (v == '<') {
              _delete();
            } else {
              _add(v);
            }
          },
        ),
      ],
    );
  }
}

class _DotRow extends StatelessWidget {
  const _DotRow({required this.length, required this.filled, required this.lum});

  final int length;
  final int filled;
  final LumColors lum;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final isFilled = i < filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 14,
          height: 14,
          margin: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? lum.accent : lum.surface2,
          ),
        );
      }),
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.keys, required this.onTap, required this.lum});

  final List<String> keys;
  final ValueChanged<String> onTap;
  final LumColors lum;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: keys
            .map((key) =>
                _KeyButton(label: key, lum: lum, onTap: () => onTap(key)))
            .toList(),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton(
      {required this.label, required this.onTap, required this.lum});

  final String label;
  final VoidCallback onTap;
  final LumColors lum;

  @override
  Widget build(BuildContext context) {
    final isEmpty = label.isEmpty;
    final isDelete = label == '<';

    if (isEmpty) {
      return const SizedBox(width: 72 + 12, height: 56);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: onTap,
        child: ClayContainer(
          variant: ClayVariant.soft,
          color: lum.surface,
          borderRadius: AppRadius.md,
          isDark: lum.isDark,
          width: 72,
          height: 56,
          child: Center(
            child: isDelete
                ? Icon(Icons.backspace_outlined,
                    color: lum.textTertiary, size: 22)
                : Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppTypography.mono,
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: lum.textPrimary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
