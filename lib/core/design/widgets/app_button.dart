import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_radius.dart';
import '../app_typography.dart';

enum AppButtonVariant { filled, tinted, plain, destructive }

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.loading = false,
    this.fullWidth = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final bool fullWidth;
  final IconData? icon;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  Color get _textColor {
    switch (widget.variant) {
      case AppButtonVariant.filled:
        return Colors.white;
      case AppButtonVariant.destructive:
        return Colors.white;
      case AppButtonVariant.tinted:
        return AppColors.accent;
      case AppButtonVariant.plain:
        return AppColors.accent;
    }
  }

  Color get _bgColor {
    switch (widget.variant) {
      case AppButtonVariant.filled:
        return AppColors.accent;
      case AppButtonVariant.destructive:
        return AppColors.destructive;
      case AppButtonVariant.tinted:
        return AppColors.accent.withValues(alpha: 0.1);
      case AppButtonVariant.plain:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _enabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: _enabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: _enabled ? () => setState(() => _isPressed = false) : null,
      onTap: _enabled ? widget.onPressed : null,
      child: AnimatedOpacity(
        opacity: _isPressed ? 0.85 : _enabled ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 50,
          width: widget.fullWidth ? double.infinity : null,
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          child: Center(
            child: widget.loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(_textColor),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: _textColor, size: 18),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        style: AppTypography.callout.copyWith(
                          color: _textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
