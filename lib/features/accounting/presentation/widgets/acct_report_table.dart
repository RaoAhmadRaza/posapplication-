import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_card.dart';
import 'accounting_ui.dart';

/// One trial-balance line.
class AcctReportRow {
  const AcctReportRow({
    required this.code,
    required this.name,
    required this.debit,
    required this.credit,
  });

  final String code;
  final String name;
  final double debit;
  final double credit;
}

/// The trial-balance table: an optional balanced badge, a column header band,
/// Account/Debit/Credit rows and a total row.
class AcctReportTable extends StatelessWidget {
  const AcctReportTable({
    super.key,
    required this.rows,
    required this.totalDebit,
    required this.totalCredit,
    this.badge,
  });

  final List<AcctReportRow> rows;
  final double totalDebit;
  final double totalCredit;

  /// Rendered top-right of the card (e.g. an AppPill "Balanced").
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final headStyle = acctHeaderColStyle(context);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (badge != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Align(alignment: Alignment.centerLeft, child: badge),
            ),
          Container(
            decoration: acctHeaderRowDecoration(context),
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(child: Text('ACCOUNT', style: headStyle)),
                SizedBox(
                  width: 100,
                  child:
                      Text('DEBIT', style: headStyle, textAlign: TextAlign.right),
                ),
                SizedBox(
                  width: 100,
                  child: Text('CREDIT',
                      style: headStyle, textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
          for (final r in rows) _Row(row: r),
          Container(
            color: lum.surface2,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total',
                    style: AppTypography.subhead.copyWith(
                      fontWeight: FontWeight.w700,
                      color: lum.textPrimary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: AcctMono(formatAmount(totalDebit, decimals: 0),
                      weight: FontWeight.w700, size: 13.5),
                ),
                SizedBox(
                  width: 100,
                  child: AcctMono(formatAmount(totalCredit, decimals: 0),
                      weight: FontWeight.w700, size: 13.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row});

  final AcctReportRow row;

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
        children: [
          Expanded(
            child: Row(
              children: [
                AcctCodeChip(row.code),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    row.name,
                    style: AppTypography.subhead.copyWith(
                      fontSize: 14,
                      color: lum.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 100, child: AcctMono(debitStr, size: 13)),
          SizedBox(width: 100, child: AcctMono(creditStr, size: 13)),
        ],
      ),
    );
  }
}
