import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_pill.dart';

/// Shared accounting-module presentation helpers. Theme-aware (`context.lum`),
/// no business logic — just the LUMINA look for the module's rows and pills.

/// A soft clay square holding a Lucide glyph, as the design's list/hub icon.
/// Passes an explicit fill: [ClayVariant.soft] is fine, but the callers choose
/// the tint so revenue/expense/status rows read differently.
class AcctIconTile extends StatelessWidget {
  const AcctIconTile({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
    this.size = 40,
    this.iconSize = 20,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return ClayContainer(
      variant: ClayVariant.soft,
      color: background,
      borderRadius: 13,
      isDark: lum.isDark,
      width: size,
      height: size,
      child: Center(child: Icon(icon, size: iconSize, color: foreground)),
    );
  }
}

/// Uppercase, tracked section label (the design's tiny caption eyebrows).
class AcctSectionLabel extends StatelessWidget {
  const AcctSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Text(
      text.toUpperCase(),
      style: AppTypography.caption.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
        color: lum.g500,
      ),
    );
  }
}

/// Tabular monospaced figure for table cells (no currency prefix). Use
/// [AppMoneyText] where the design shows the small `PKR` superscript instead.
class AcctMono extends StatelessWidget {
  const AcctMono(
    this.text, {
    super.key,
    this.color,
    this.weight = FontWeight.w500,
    this.size = 14,
    this.align = TextAlign.right,
  });

  final String text;
  final Color? color;
  final FontWeight weight;
  final double size;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Text(
      text,
      textAlign: align,
      style: TextStyle(
        fontFamily: AppTypography.mono,
        fontFeatures: const [FontFeature.tabularFigures()],
        fontSize: size,
        fontWeight: weight,
        letterSpacing: -0.1,
        color: color ?? lum.textPrimary,
      ),
    );
  }
}

/// The mono account-code chip (e.g. `1010`) the design paints in accent-soft.
class AcctCodeChip extends StatelessWidget {
  const AcctCodeChip(this.code, {super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: lum.accentSoft,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontFamily: AppTypography.mono,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: lum.accentPress,
        ),
      ),
    );
  }
}

/// Muted table-header row style used by ledgers, trial balance and journal
/// detail (the design's `g50` header band). Returns a decoration + text style.
BoxDecoration acctHeaderRowDecoration(BuildContext context) {
  final lum = context.lum;
  return BoxDecoration(
    color: lum.surface2,
    border: Border(
      top: BorderSide(color: lum.hairline),
      bottom: BorderSide(color: lum.hairline),
    ),
  );
}

TextStyle acctHeaderColStyle(BuildContext context) {
  final lum = context.lum;
  return AppTypography.caption.copyWith(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    color: lum.g500,
  );
}

/// Journal/voucher reference type → pill tone. Money-in reads success,
/// money-out reads danger, adjustments read transit, else neutral.
AppPillTone acctRefTone(String? referenceType) {
  final t = (referenceType ?? '').toUpperCase();
  if (t.contains('RECEIPT') ||
      t == 'SALE' ||
      t == 'CUSTOMER_PAYMENT') {
    return AppPillTone.success;
  }
  if (t.contains('PAYMENT') || t.contains('SUPPLIER') || t == 'PURCHASE_RETURN') {
    return AppPillTone.danger;
  }
  if (t.contains('JOURNAL') || t.contains('CONTRA') || t.contains('ADJ') ||
      t.contains('PURCHASE')) {
    return AppPillTone.transit;
  }
  return AppPillTone.neutral;
}

/// Humanised reference-type label ("Manual" when there's none).
String acctRefLabel(String? referenceType) {
  final t = referenceType;
  if (t == null || t.isEmpty) return 'Manual';
  return t
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}')
      .join(' ');
}
