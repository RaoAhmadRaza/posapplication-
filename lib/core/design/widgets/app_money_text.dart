import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_typography.dart';
import '../format.dart';

/// Money value rendered the LUMINA way: a small, muted currency prefix followed
/// by a tabular mono number.
///
/// The prefix is sized at 0.62x the number and raised slightly off the baseline,
/// so 'PKR' reads as an annotation rather than part of the figure. Number
/// formatting is delegated to [formatAmount] — never reimplemented here.
class AppMoneyText extends StatelessWidget {
  const AppMoneyText(
    this.value, {
    super.key,
    this.size = 21,
    this.decimals = 0,
    this.color,
  });

  final num value;
  final double size;
  final int decimals;

  /// Overrides the number colour (e.g. danger for negative ledger amounts).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$displayCurrency ',
            style: TextStyle(
              fontFamily: AppTypography.mono,
              fontSize: size * 0.62,
              fontWeight: FontWeight.w500,
              color: lum.g400,
            ),
          ),
          TextSpan(text: formatAmount(value, decimals: decimals)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.monoValue.copyWith(
        fontSize: size,
        letterSpacing: -size * 0.01,
        color: color ?? lum.textPrimary,
      ),
    );
  }
}
