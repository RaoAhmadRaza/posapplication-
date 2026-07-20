import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import '../app_colors.dart';
import '../app_radius.dart';
import '../app_spacing.dart';
import '../app_typography.dart';

class AppOtpField extends StatelessWidget {
  const AppOtpField({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.onChanged,
  });

  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final textStyle = AppTypography.monoLarge.copyWith(
      fontSize: 22,
      color: lum.textPrimary,
    );

    PinTheme cell({required Color border, double width = 1}) => PinTheme(
          width: 48,
          height: 56,
          textStyle: textStyle,
          decoration: BoxDecoration(
            color: lum.surface2,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: border, width: width),
          ),
        );

    return Pinput(
      length: length,
      onCompleted: onCompleted,
      onChanged: onChanged,
      defaultPinTheme: cell(border: lum.hairline),
      focusedPinTheme: cell(border: lum.accent, width: 1.5),
      submittedPinTheme: cell(border: lum.hairline),
      errorPinTheme: cell(border: lum.danger, width: 1.5),
      separatorBuilder: (_) => const SizedBox(width: AppSpacing.sm),
      keyboardType: TextInputType.number,
      mainAxisAlignment: MainAxisAlignment.center,
      pinAnimationType: PinAnimationType.fade,
    );
  }
}
