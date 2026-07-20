import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_motion.dart';
import '../app_radius.dart';
import '../app_typography.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData prefixIcon;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final Iterable<String>? autofillHints;
  final bool enabled;
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.errorText,
    this.onSubmitted,
    this.onChanged,
    this.autofocus = false,
    this.autofillHints,
    this.enabled = true,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final FocusNode _focus = FocusNode()..addListener(() => setState(() {}));
  late bool _hidden = widget.obscure;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final focused = _focus.hasFocus;
    final hasError = widget.errorText != null;

    final row = Row(
      children: [
        Icon(
          widget.prefixIcon,
          color: focused ? lum.accent : lum.g400,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            obscureText: _hidden,
            enabled: widget.enabled,
            autofocus: widget.autofocus,
            autofillHints: widget.autofillHints,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            onSubmitted: widget.onSubmitted,
            onChanged: widget.onChanged,
            style: AppTypography.fieldText.copyWith(color: lum.textPrimary),
            cursorColor: lum.accent,
            decoration: InputDecoration(
              isCollapsed: true,
              // Theme sets filled:true/fillColor:surface2 — kill it here or the
              // TextField paints its own grey pill inside our well (nested box).
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: widget.hint,
              hintStyle:
                  AppTypography.fieldHint.copyWith(color: lum.textTertiary),
            ),
          ),
        ),
        if (widget.obscure)
          Semantics(
            button: true,
            label: _hidden ? 'Show password' : 'Hide password',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _hidden = !_hidden),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  _hidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: lum.g400,
                  size: 20,
                ),
              ),
            ),
          ),
      ],
    );

    // ONE stable container — never swap widget type on focus, or the TextField
    // gets reparented and remounted, dropping the first tap (double-click bug).
    // Rest → flat grey fill, no border. Focused/error → white + coloured ring
    // + halo. Border width stays constant (transparent when at rest) so the
    // content never shifts.
    final active = focused || hasError;
    final ring = hasError ? lum.danger : lum.accent;
    final well = AnimatedContainer(
      duration: AppMotion.fast,
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: active ? lum.surface : lum.surface2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: active ? ring : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: lum.accent.withValues(alpha: lum.isDark ? 0.35 : 0.18),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: row,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            widget.label,
            style: AppTypography.fieldLabel.copyWith(color: lum.g700),
          ),
        ),
        well,
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 2, top: 7),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 13, color: lum.dangerText),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.errorText!,
                    style:
                        AppTypography.errorText.copyWith(color: lum.dangerText),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
