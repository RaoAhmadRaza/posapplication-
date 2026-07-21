import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../app_colors.dart';
import '../app_motion.dart';
import '../app_radius.dart';
import '../app_typography.dart';

/// One entry in an [AppDropdown].
@immutable
class AppDropdownOption<T> {
  const AppDropdownOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// The design system's select control: a 50px inset well with a rotating
/// chevron over a floating menu.
///
/// Built on [MenuAnchor] so outside-tap dismissal, focus traversal and keyboard
/// handling come from the framework rather than a hand-rolled overlay.
class AppDropdown<T> extends StatefulWidget {
  const AppDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onSelected,
    this.placeholder = 'Select…',
    this.enabled = true,
  });

  final T? value;
  final List<AppDropdownOption<T>> options;
  final ValueChanged<T> onSelected;
  final String placeholder;
  final bool enabled;

  @override
  State<AppDropdown<T>> createState() => _AppDropdownState<T>();
}

class _AppDropdownState<T> extends State<AppDropdown<T>> {
  final _controller = MenuController();
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final live = widget.enabled && widget.options.isNotEmpty;

    // A value the caller's option list does not cover is still a real stored
    // value (a branch on a currency outside the supplied list, say). Show it
    // rather than silently reading as "nothing selected".
    final options = [
      ...widget.options,
      if (widget.value != null &&
          !widget.options.any((o) => o.value == widget.value))
        AppDropdownOption<T>(
          value: widget.value as T,
          label: '${widget.value}',
        ),
    ];
    final current =
        options.where((o) => o.value == widget.value).firstOrNull;

    final button = AnimatedContainer(
      duration: AppMotion.fast,
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: live ? lum.surface2 : lum.g100,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: _open ? lum.accent : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: _open
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
          Expanded(
            child: Text(
              current?.label ?? widget.placeholder,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.fieldText.copyWith(
                color: current == null ? lum.textTertiary : lum.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedRotation(
            duration: AppMotion.fast,
            turns: _open ? 0.5 : 0,
            child: Icon(
              LucideIcons.chevronDown,
              size: 18,
              color: _open ? lum.accent : lum.g500,
            ),
          ),
        ],
      ),
    );

    // The menu is sized to the well it drops out of, as in the spec, so it
    // needs the laid-out width rather than its own intrinsic content width.
    return LayoutBuilder(
      builder: (context, constraints) => MenuAnchor(
        controller: _controller,
        onOpen: () => setState(() => _open = true),
        onClose: () => setState(() => _open = false),
        alignmentOffset: const Offset(0, 6),
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(lum.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
          minimumSize: WidgetStatePropertyAll(
            Size(constraints.maxWidth.isFinite ? constraints.maxWidth : 0, 0),
          ),
          maximumSize: const WidgetStatePropertyAll(Size.fromHeight(260)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(color: lum.hairline),
            ),
          ),
        ),
        menuChildren: [
          for (final option in options)
            _MenuRow<T>(
              option: option,
              selected: option.value == widget.value,
              onTap: () {
                _controller.close();
                widget.onSelected(option.value);
              },
            ),
        ],
        builder: (context, controller, _) => Semantics(
          button: true,
          enabled: live,
          label: current?.label ?? widget.placeholder,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: live
                ? () =>
                    controller.isOpen ? controller.close() : controller.open()
                : null,
            child: Opacity(opacity: live ? 1 : 0.7, child: button),
          ),
        ),
      ),
    );
  }
}

class _MenuRow<T> extends StatelessWidget {
  const _MenuRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AppDropdownOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final fg = selected ? lum.accentPress : lum.textPrimary;
    return MenuItemButton(
      onPressed: onTap,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14),
        ),
        backgroundColor: WidgetStatePropertyAll(
          selected ? lum.accentSoft : Colors.transparent,
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      trailingIcon:
          selected ? Icon(LucideIcons.check, size: 17, color: fg) : null,
      child: Text(
        option.label,
        style: AppTypography.body.copyWith(
          color: fg,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }
}
