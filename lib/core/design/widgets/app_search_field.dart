import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../app_colors.dart';
import '../app_radius.dart';
import '../app_typography.dart';
import '../clay.dart';

/// The design's list search bar: a 48px inset well with a leading magnifier and
/// a trailing clear button that appears once there is text.
///
/// Deliberately not [AppTextField] — that widget carries a label above a
/// bordered field; this is a bare well. The POS terminal hand-rolled the same
/// shape before this existed; it keeps its own copy because it also hosts the
/// scan button.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onSubmitted,
    this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onSubmitted;

  /// Called after the field is emptied by the clear button, so the caller can
  /// drop any debounce and reload immediately.
  final VoidCallback? onClear;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  /// Only the clear button's visibility depends on the text, so rebuild just
  /// when it crosses empty/non-empty.
  bool _hasText = false;

  void _onChanged() {
    final has = widget.controller.text.isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;

    return ClayContainer(
      variant: ClayVariant.inset,
      color: lum.surface2,
      borderRadius: AppRadius.md,
      isDark: lum.isDark,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 18, color: lum.g400),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              textInputAction: TextInputAction.search,
              onSubmitted: widget.onSubmitted,
              style: AppTypography.fieldText.copyWith(color: lum.textPrimary),
              cursorColor: lum.accent,
              decoration: InputDecoration(
                isCollapsed: true,
                // The theme fills inputs; without this a second grey pill
                // paints inside the well.
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
          if (_hasText)
            Semantics(
              button: true,
              label: 'Clear search',
              child: InkWell(
                onTap: () {
                  widget.controller.clear();
                  widget.onClear?.call();
                },
                borderRadius: BorderRadius.circular(AppRadius.pill),
                // 44dp target around a 17px glyph.
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(LucideIcons.x, size: 17, color: lum.g400),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
