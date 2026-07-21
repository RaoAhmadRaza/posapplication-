import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_colors.dart';
import '../app_motion.dart';
import '../app_radius.dart';
import '../app_typography.dart';
import '../format.dart';

/// The design's money well: a muted currency prefix followed by a large tabular
/// mono amount. Used for the opening float, the counted cash and tender rows.
///
/// Kept separate from [AppTextField] because the figure carries the screen — it
/// is mono, oversized and prefixed, none of which the general field supports.
class AppMoneyField extends StatefulWidget {
  const AppMoneyField({
    super.key,
    required this.controller,
    this.label,
    this.hint = '0',
    this.fontSize = 26,
    this.height = 56,
    this.autofocus = false,
    this.enabled = true,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.trailing,
  });

  final TextEditingController controller;

  /// Field label above the well; omitted when the row already reads as one.
  final String? label;
  final String hint;
  final double fontSize;
  final double height;
  final bool autofocus;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Optional control inside the well (e.g. the payment sheet's 'Exact' chip).
  final Widget? trailing;

  @override
  State<AppMoneyField> createState() => _AppMoneyFieldState();
}

class _AppMoneyFieldState extends State<AppMoneyField> {
  late final FocusNode _focus = FocusNode()..addListener(() => setState(() {}));

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
    final active = focused || hasError;
    final ring = hasError ? lum.danger : lum.accent;

    // One stable container across states — swapping widget type on focus
    // reparents the TextField and swallows the first tap (AppTextField lesson).
    final well = AnimatedContainer(
      duration: AppMotion.fast,
      height: widget.height,
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
      child: Row(
        children: [
          Text(
            displayCurrency,
            style: AppTypography.monoValue.copyWith(
              fontSize: 15,
              color: lum.g400,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              enabled: widget.enabled,
              autofocus: widget.autofocus,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              cursorColor: lum.accent,
              style: AppTypography.monoValue.copyWith(
                fontSize: widget.fontSize,
                fontWeight: FontWeight.w600,
                color: lum.textPrimary,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                // The theme fills inputs; without this the TextField paints a
                // second grey pill inside our well.
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: widget.hint,
                hintStyle: AppTypography.monoValue.copyWith(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w600,
                  color: lum.textDisabled,
                ),
              ),
            ),
          ),
          ?widget.trailing,
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              widget.label!,
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
