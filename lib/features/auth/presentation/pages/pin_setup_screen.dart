import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/services/pin_service.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String? _firstPin;
  String? _errorMessage;
  bool _loading = false;

  void _onFirstComplete(String pin) {
    setState(() {
      _firstPin = pin;
      _errorMessage = null;
    });
  }

  void _onConfirmComplete(String pin) {
    if (pin == _firstPin) {
      _save(pin);
    } else {
      setState(() {
        _firstPin = null;
        _errorMessage = 'PINs do not match. Please try again.';
      });
    }
  }

  Future<void> _save(String pin) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await PinService.instance.setPin(pin);
    } on Exception {
      // Never leave the spinner spinning — a storage failure must let the user
      // retry instead of bricking the screen (e.g. Keychain access denied).
      if (!mounted) return;
      setState(() {
        _loading = false;
        _firstPin = null;
        _errorMessage = 'Could not save your PIN. Please try again.';
      });
      return;
    }
    if (!mounted) return;
    if (context.mounted) {
      showAppToast(context, 'PIN set', type: BannerType.success);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;

    return Scaffold(
      backgroundColor: lum.paper,
      appBar: AppBar(
        backgroundColor: lum.paper,
        surfaceTintColor: lum.paper,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: lum.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Set PIN',
          style: AppTypography.title3.copyWith(color: lum.textPrimary),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
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
                      _firstPin == null
                          ? 'Choose a 4-digit PIN for quick login.'
                          : 'Confirm your PIN.',
                      textAlign: TextAlign.center,
                      style: AppTypography.subhead
                          .copyWith(color: lum.textSecondary),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.base),
                      AppInlineBanner(message: _errorMessage!),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    _loading
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: lum.accent,
                              ),
                            ),
                          )
                        : _ClayPinPad(
                            length: 4,
                            onCompleted: _firstPin == null
                                ? _onFirstComplete
                                : _onConfirmComplete,
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Themed clay PIN pad — inset dot wells + raised clay keys, reading colours
/// from [LumColors] so dark ("Counter") mode renders correctly. Mirrors the
/// core [PinPad] accumulation logic (add / delete / fire on full).
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DotRow(length: widget.length, filled: _pin.length),
        const SizedBox(height: AppSpacing.xl),
        _KeyRow(keys: const ['1', '2', '3'], onTap: _add),
        _KeyRow(keys: const ['4', '5', '6'], onTap: _add),
        _KeyRow(keys: const ['7', '8', '9'], onTap: _add),
        _KeyRow(
          keys: const ['', '0', '<'],
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
  const _DotRow({required this.length, required this.filled});

  final int length;
  final int filled;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final isFilled = i < filled;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: isFilled
              ? Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: lum.accent,
                  ),
                )
              : ClayContainer(
                  variant: ClayVariant.inset,
                  color: lum.surface2,
                  borderRadius: 8,
                  isDark: lum.isDark,
                  width: 16,
                  height: 16,
                  child: const SizedBox.shrink(),
                ),
        );
      }),
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.keys, required this.onTap});

  final List<String> keys;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: keys
            .map((key) => _KeyButton(label: key, onTap: () => onTap(key)))
            .toList(),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final isEmpty = label.isEmpty;
    final isDelete = label == '<';

    if (isEmpty) {
      return const SizedBox(
        width: 72 + AppSpacing.sm * 2,
        height: 56,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
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
                    style: AppTypography.monoLarge.copyWith(
                      fontSize: 24,
                      color: lum.textPrimary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
