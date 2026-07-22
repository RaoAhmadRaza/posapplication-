import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../domain/entities/supplier_ledger.dart';

/// One rendered ledger line. The opening balance arrives from the RPC as a
/// scalar rather than an entry, so it is adapted into this shape with no date.
class _Line {
  const _Line({
    required this.reference,
    required this.typeLabel,
    required this.icon,
    required this.tint,
    required this.amount,
    required this.runningBalance,
    this.date,
    this.mono = true,
  });

  final String reference;
  final String typeLabel;
  final IconData icon;
  final Color tint;

  /// Positive increases what we owe; negative reduces it.
  final double amount;
  final double runningBalance;
  final DateTime? date;
  final bool mono;
}

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final day = d.day.toString().padLeft(2, '0');
  return '$day ${months[d.month - 1]} ${d.year}';
}

/// The design's ledger card: balance header, a column-header strip and one row
/// per transaction, newest first.
class SupplierLedgerCard extends StatelessWidget {
  const SupplierLedgerCard({
    super.key,
    required this.ledger,
    required this.isWide,
    this.footer,
  });

  final SupplierLedger ledger;
  final bool isWide;

  /// Record-payment action, already permission-gated by the caller.
  final Widget? footer;

  List<_Line> _lines(LumColors lum) {
    final lines = <_Line>[
      for (final e in ledger.entries)
        _line(e, lum),
    ];
    // Newest first, matching the design.
    final reversed = lines.reversed.toList();
    if (ledger.openingBalance != 0) {
      reversed.add(_Line(
        reference: 'Opening balance',
        typeLabel: 'Opening balance',
        icon: LucideIcons.wallet,
        tint: lum.g500,
        amount: ledger.openingBalance,
        runningBalance: ledger.openingBalance,
        mono: false,
      ));
    }
    return reversed;
  }

  _Line _line(SupplierLedgerEntry e, LumColors lum) {
    final (IconData icon, Color tint, String label) = switch (e.kind) {
      'INVOICE' => (LucideIcons.receipt, lum.textPrimary, 'Purchase invoice'),
      'RETURN' => (
          LucideIcons.cornerUpLeft,
          lum.transitText,
          'Purchase return',
        ),
      _ => (LucideIcons.banknote, lum.successText, 'Payment'),
    };
    return _Line(
      reference: e.reference ?? label,
      typeLabel: label,
      icon: icon,
      tint: tint,
      amount: e.debit - e.credit,
      runningBalance: e.runningBalance,
      date: e.timestamp,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final owed = ledger.currentBalance;
    final lines = _lines(lum);

    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                  isWide ? 24 : 18, isWide ? 22 : 18, isWide ? 24 : 18, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ledger',
                      style: AppTypography.title2
                          .copyWith(fontSize: 18, color: lum.textPrimary),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _MicroLabel('Current balance'),
                      const SizedBox(height: 2),
                      AppMoneyText(
                        owed,
                        size: 22,
                        decimals: 2,
                        color: owed > 0 ? lum.dangerText : lum.successText,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (lines.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 36),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: lum.hairline)),
                ),
                child: Text(
                  'No transactions yet.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(color: lum.g500),
                ),
              )
            else ...[
              _HeaderStrip(isWide: isWide),
              for (var i = 0; i < lines.length; i++)
                _LedgerRow(
                  line: lines[i],
                  isWide: isWide,
                  showDivider: i < lines.length - 1,
                ),
            ],
            if (footer != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: lum.hairline)),
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

class _MicroLabel extends StatelessWidget {
  const _MicroLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Text(
      text.toUpperCase(),
      style: AppTypography.caption.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.55,
        color: lum.g400,
      ),
    );
  }
}

/// Static column labels — the design's headers are not sortable, so these carry
/// no tap target.
class _HeaderStrip extends StatelessWidget {
  const _HeaderStrip({required this.isWide});
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final style = AppTypography.caption.copyWith(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.75,
      color: lum.g500,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: lum.surface2,
        border: Border(
          top: BorderSide(color: lum.hairline),
          bottom: BorderSide(color: lum.hairline),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 16, child: Text('TRANSACTION', style: style)),
          if (isWide)
            Expanded(
              flex: 10,
              child:
                  Text('BALANCE', textAlign: TextAlign.right, style: style),
            ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text('AMOUNT', textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.line,
    required this.isWide,
    required this.showDivider,
  });

  final _Line line;
  final bool isWide;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final isCredit = line.amount < 0;
    final sign = isCredit ? '−' : '+';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: lum.hairline))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 16,
            child: Row(
              children: [
                ClayContainer(
                  variant: ClayVariant.soft,
                  color: lum.surface2,
                  borderRadius: 9,
                  isDark: lum.isDark,
                  width: 34,
                  height: 34,
                  child: Center(
                    child: Icon(line.icon, size: 16, color: line.tint),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.reference,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: (line.mono
                                ? AppTypography.monoValue
                                : AppTypography.body)
                            .copyWith(fontSize: 13.5, color: lum.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        // The opening balance has no date in the payload — the
                        // RPC returns it as a scalar, so none is invented.
                        '${line.typeLabel} · '
                        '${line.date == null ? '—' : _formatDate(line.date!)}',
                        style: AppTypography.caption
                            .copyWith(fontSize: 12, color: lum.g500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isWide)
            Expanded(
              flex: 10,
              child: Text(
                formatAmount(line.runningBalance),
                textAlign: TextAlign.right,
                style: AppTypography.monoValue
                    .copyWith(fontSize: 13, color: lum.g500),
              ),
            ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(
              '$sign ${formatAmount(line.amount.abs())}',
              textAlign: TextAlign.right,
              style: AppTypography.monoValue.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isCredit ? lum.successText : lum.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
