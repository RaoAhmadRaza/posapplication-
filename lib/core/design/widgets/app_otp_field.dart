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
  });

  final int length;
  final ValueChanged<String> onCompleted;

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 48,
      height: 56,
      textStyle: AppTypography.headline,
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
    );

    final focusedPinTheme = PinTheme(
      width: 48,
      height: 56,
      textStyle: AppTypography.headline,
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.accent, width: 1.5),
      ),
    );

    return Pinput(
      length: length,
      onCompleted: onCompleted,
      defaultPinTheme: defaultPinTheme,
      focusedPinTheme: focusedPinTheme,
      submittedPinTheme: defaultPinTheme,
      errorPinTheme: PinTheme(
        width: 48,
        height: 56,
        textStyle: AppTypography.headline,
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(AppRadius.field),
          border: Border.all(color: AppColors.destructive, width: 1.5),
        ),
      ),
      separatorBuilder: (_) => const SizedBox(width: AppSpacing.sm),
      keyboardType: TextInputType.number,
      mainAxisAlignment: MainAxisAlignment.center,
      pinAnimationType: PinAnimationType.fade,
    );
  }
}
