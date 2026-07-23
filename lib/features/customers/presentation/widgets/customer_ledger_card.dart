import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../domain/entities/customer_ledger.dart';

/// One rendered ledger line. The opening balance arrives from the RPC as a
/// scalar rather than an entry, so it is adapted into this shape with no date.
class _Line {
  const _Line({
    required this.reference,
    required this.typeLabel,
    required this.amount,
    required this.runningBalance,
    this.date,
  });

  final String reference;
  final String typeLabel;

  /// Positive increases what the customer owes (invoice); negative reduces it
  /// (payment).
  final double amount;
  final double runningBalance;
  final DateTime? date;
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime d) => '${_months[d.month - 1]} '
    '${d.day.toString().padLeft(2, '0')}';

/// The design's customer ledger card: a "Ledger / Running balance" header and
/// one row per transaction newest-first, each showing the signed amount and the
/// running balance. Always renders — an empty ledger shows an in-card message
/// rather than being dropped.
class CustomerLedgerCard extends StatelessWidget {
  const CustomerLedgerCard({
    super.key,
    required this.ledger,
    required this.isWide,
  });

  final CustomerLedger ledger;
  final bool isWide;

  List<_Line> _lines() {
    final lines = <_Line>[
      for (final e in ledger.entries)
        _Line(
          reference: e.reference ?? _labelFor(e.kind),
          typeLabel: _labelFor(e.kind),
          amount: e.debit - e.credit,
          runningBalance: e.runningBalance,
          date: e.timestamp,
        ),
    ];
    // Newest first, matching the design.
    final reversed = lines.reversed.toList();
    if (ledger.openingBalance != 0) {
      reversed.add(_Line(
        reference: 'Opening balance',
        typeLabel: 'Opening balance',
        amount: ledger.openingBalance,
        runningBalance: ledger.openingBalance,
      ));
    }
    return reversed;
  }

  String _labelFor(String kind) => switch (kind) {
        'INVOICE' => 'Invoice',
        'PAYMENT' => 'Payment',
        _ => kind,
      };

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final lines = _lines();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ledger',
                  style: AppTypography.title2
                      .copyWith(fontSize: 16, color: lum.textPrimary),
                ),
              ),
              Text(
                'Running balance',
                style: AppTypography.caption.copyWith(color: lum.g500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Text(
                    'No transactions yet.',
                    style: AppTypography.body.copyWith(color: lum.g500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sales and payments will appear here.',
                    style: AppTypography.footnote.copyWith(color: lum.g400),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < lines.length; i++)
              _LedgerRow(line: lines[i], showDivider: i < lines.length - 1),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.line, required this.showDivider});

  final _Line line;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final isCredit = line.amount < 0;
    final sign = isCredit ? '−' : '+';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: lum.hairline))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        line.reference,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.monoValue.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: lum.textPrimary,
                        ),
                      ),
                    ),
                    if (line.date != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(line.date!),
                        style: AppTypography.caption.copyWith(color: lum.g400),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  line.typeLabel,
                  style: AppTypography.footnote.copyWith(color: lum.g500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sign ${formatAmount(line.amount.abs())}',
                style: AppTypography.monoValue.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isCredit ? lum.successText : lum.dangerText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatAmount(line.runningBalance),
                style: AppTypography.monoValue
                    .copyWith(fontSize: 12, color: lum.g400),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
