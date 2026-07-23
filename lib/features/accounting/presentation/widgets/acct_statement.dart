import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_money_text.dart';

/// One statement line (account name + amount).
typedef AcctStatementLine = ({String name, double amount});

/// A P&L / balance-sheet section: an uppercase heading, the account lines, and
/// an optional subtotal row. Reused for Revenue / Expenses / Assets /
/// Liabilities / Equity.
class AcctStatementSection extends StatelessWidget {
  const AcctStatementSection({
    super.key,
    required this.heading,
    required this.lines,
    this.subtotalLabel,
    this.subtotalAmount,
    this.topGap = false,
  });

  final String heading;
  final List<AcctStatementLine> lines;
  final String? subtotalLabel;
  final double? subtotalAmount;

  /// Adds space above the heading (for a second/third section in a card).
  final bool topGap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (topGap) const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            heading.toUpperCase(),
            style: AppTypography.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: lum.g600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: lum.hairline)),
          ),
          child: Column(
            children: [
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          l.name,
                          style: AppTypography.body.copyWith(color: lum.g700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      AppMoneyText(l.amount, size: 14),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (subtotalLabel != null && subtotalAmount != null)
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: lum.hairline)),
            ),
            padding: const EdgeInsets.only(top: 11, bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  subtotalLabel!,
                  style: AppTypography.subhead.copyWith(
                    fontWeight: FontWeight.w600,
                    color: lum.textPrimary,
                  ),
                ),
                AppMoneyText(subtotalAmount!, size: 14, decimals: 0),
              ],
            ),
          ),
      ],
    );
  }
}

/// The dark summary strip (net profit / liabilities + equity). Clay can't paint
/// a full dark fill, so this is a plain rounded [Container] in ink with inverse
/// text — additive and module-local.
class AcctNetRow extends StatelessWidget {
  const AcctNetRow({super.key, required this.label, required this.amount});

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: lum.ink,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.headline.copyWith(
              fontSize: 14.5,
              color: lum.paper,
            ),
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$displayCurrency ',
                  style: TextStyle(
                    fontFamily: AppTypography.mono,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: lum.paper.withValues(alpha: 0.7),
                  ),
                ),
                TextSpan(
                  text: formatAmount(amount, decimals: 0),
                  style: TextStyle(
                    fontFamily: AppTypography.mono,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: lum.paper,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
