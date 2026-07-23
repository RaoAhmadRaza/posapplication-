import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import 'accounting_ui.dart';

/// One running-balance ledger line (used by account ledger + cash/bank book).
class AcctLedgerRow {
  const AcctLedgerRow({
    required this.date,
    required this.particulars,
    this.reference,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  final String date;
  final String particulars;
  final String? reference;
  final double debit;
  final double credit;
  final double balance;
}

/// A ledger card: an opening-balance row, a column header band, then the
/// running-balance rows. [inOut] switches the Debit/Credit labels to In/Out and
/// tints the columns (cash & bank book) — otherwise plain debit/credit.
class AcctLedgerCard extends StatelessWidget {
  const AcctLedgerCard({
    super.key,
    required this.openingBalance,
    required this.rows,
    this.openingLabel = 'Opening balance',
    this.inOut = false,
  });

  final double openingBalance;
  final List<AcctLedgerRow> rows;
  final String openingLabel;
  final bool inOut;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  openingLabel,
                  style: AppTypography.subhead.copyWith(color: lum.g700),
                ),
                AppMoneyText(openingBalance, size: 15),
              ],
            ),
          ),
          _HeaderRow(inOut: inOut),
          for (final r in rows) _EntryRow(row: r, inOut: inOut),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.inOut});

  final bool inOut;

  @override
  Widget build(BuildContext context) {
    final style = acctHeaderColStyle(context);
    return Container(
      decoration: acctHeaderRowDecoration(context),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          SizedBox(width: 54, child: Text('DATE', style: style)),
          const SizedBox(width: 12),
          Expanded(child: Text('PARTICULARS', style: style)),
          SizedBox(
            width: 74,
            child: Text(inOut ? 'IN' : 'DEBIT',
                style: style, textAlign: TextAlign.right),
          ),
          SizedBox(
            width: 74,
            child: Text(inOut ? 'OUT' : 'CREDIT',
                style: style, textAlign: TextAlign.right),
          ),
          SizedBox(
            width: 90,
            child: Text('BALANCE', style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.row, required this.inOut});

  final AcctLedgerRow row;
  final bool inOut;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final debitStr = row.debit == 0 ? '—' : formatAmount(row.debit, decimals: 0);
    final creditStr =
        row.credit == 0 ? '—' : formatAmount(row.credit, decimals: 0);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: lum.hairline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 54,
            child: AcctMono(row.date,
                align: TextAlign.left, size: 12, color: lum.g500),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  row.particulars,
                  style: AppTypography.subhead.copyWith(
                    fontSize: 13.5,
                    color: lum.textPrimary,
                  ),
                ),
                if (row.reference != null && row.reference!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: AcctMono(row.reference!,
                        align: TextAlign.left, size: 11.5, color: lum.g500),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 74,
            child: AcctMono(debitStr,
                color: inOut && row.debit != 0 ? lum.successText : null),
          ),
          SizedBox(
            width: 74,
            child: AcctMono(creditStr,
                color: inOut && row.credit != 0 ? lum.dangerText : null),
          ),
          SizedBox(
            width: 90,
            child: AcctMono(formatAmount(row.balance, decimals: 0),
                weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
