import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../design/clay.dart';

class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    this.length = 4,
    required this.onCompleted,
  });

  final int length;
  final ValueChanged<String> onCompleted;

  @override
  Widget build(BuildContext context) {
    return _PinPadStateful(length: length, onCompleted: onCompleted);
  }
}

class _PinPadStateful extends StatefulWidget {
  const _PinPadStateful({required this.length, required this.onCompleted});

  final int length;
  final ValueChanged<String> onCompleted;

  @override
  State<_PinPadStateful> createState() => _PinPadStatefulState();
}

class _PinPadStatefulState extends State<_PinPadStateful> {
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
        _KeyRow(
          keys: const ['1', '2', '3'],
          onTap: _add,
        ),
        _KeyRow(
          keys: const ['4', '5', '6'],
          onTap: _add,
        ),
        _KeyRow(
          keys: const ['7', '8', '9'],
          onTap: _add,
        ),
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
      mainAxisSize: MainAxisSize.min,
      children: List.generate(length, (i) {
        return Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < filled ? lum.accent : lum.surface2,
            boxShadow: i < filled
                ? [
                    BoxShadow(
                      color: lum.accent.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ]
                : null,
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: keys.map((key) {
          return _KeyButton(label: key, onTap: () => onTap(key));
        }).toList(),
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

    final child = Center(
      child: isDelete
          ? Icon(Icons.backspace_outlined, color: lum.textPrimary, size: 24)
          : Text(
              label,
              style: AppTypography.title2.copyWith(color: lum.textPrimary),
            ),
    );

    if (isEmpty) {
      return const SizedBox(width: 72 + AppSpacing.xs * 2, height: 56);
    }

    return Semantics(
      button: true,
      label: isDelete ? 'Delete' : label,
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: ClayContainer(
          variant: ClayVariant.soft,
          color: lum.surface,
          borderRadius: AppRadius.md,
          isDark: lum.isDark,
          width: 72,
          height: 56,
          child: child,
        ),
      ),
    ),
    );
  }
}
