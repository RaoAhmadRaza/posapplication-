import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_typography.dart';
import 'app_card.dart';

/// Clay card headed by the design's small uppercase eyebrow (`ITEMS`,
/// `PAYMENTS`, `SESSION SUMMARY`).
///
/// [padded] false lets the card run its own rows edge to edge, in which case the
/// eyebrow keeps its own inset.
class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    super.key,
    required this.eyebrow,
    required this.child,
    this.padded = true,
    this.trailing,
  });

  final String eyebrow;
  final Widget child;
  final bool padded;

  /// Optional control opposite the eyebrow (e.g. a 'View all' button).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final header = Row(
      children: [
        Expanded(
          child: Text(
            eyebrow.toUpperCase(),
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: lum.g500,
            ),
          ),
        ),
        ?trailing,
      ],
    );

    return AppCard(
      padding: padded
          ? const EdgeInsets.all(20)
          : const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: padded
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 20),
            child: header,
          ),
          SizedBox(height: padded ? 14 : 12),
          child,
        ],
      ),
    );
  }
}
