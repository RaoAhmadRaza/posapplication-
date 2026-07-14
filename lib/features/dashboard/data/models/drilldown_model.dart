import '../../../../core/design/format.dart';
import '../../domain/entities/drilldown.dart';

/// Maps DrilldownType → its RPC name, params, and per-row display + deep-link.
class DrilldownModel {
  static String rpcName(DrilldownType type) => switch (type) {
        DrilldownType.sales => 'drilldown_sales',
        DrilldownType.lowStock => 'drilldown_low_stock',
        DrilldownType.receivables => 'drilldown_receivables',
        DrilldownType.account => 'drilldown_account',
        DrilldownType.product => 'drilldown_product',
      };

  static Map<String, dynamic> params(DrilldownArgs a) => switch (a.type) {
        DrilldownType.sales => {'p_branch': a.branchId, 'p_date': a.date},
        DrilldownType.lowStock => {'p_branch': a.branchId},
        DrilldownType.receivables => {'p_branch': a.branchId},
        DrilldownType.account => {
            'p_account_code': a.entityId,
            'p_from': null,
            'p_to': null,
          },
        DrilldownType.product => {'p_product': a.entityId},
      };

  static DrilldownRow row(DrilldownType type, Map<String, dynamic> j) {
    double num(dynamic v) => double.tryParse(v.toString()) ?? 0;
    switch (type) {
      case DrilldownType.sales:
        return DrilldownRow(
          title: j['invoice_number']?.toString() ?? '—',
          subtitle: (j['status'] ?? '').toString(),
          trailing: formatPkr(num(j['grand_total'])),
          deepLink: '/sales/invoice/${j['invoice_number']}',
        );
      case DrilldownType.receivables:
        return DrilldownRow(
          title: j['invoice_number']?.toString() ?? '—',
          subtitle: '${j['customer'] ?? 'Walk-in'} · ${j['status'] ?? ''}',
          trailing: formatPkr(num(j['balance'])),
          deepLink: '/sales/invoice/${j['invoice_number']}',
        );
      case DrilldownType.lowStock:
        return DrilldownRow(
          title: j['product_name']?.toString() ?? '—',
          subtitle: (j['sku'] ?? '').toString(),
          trailing:
              '${num(j['qty_on_hand']).toStringAsFixed(0)} / ${num(j['reorder_point']).toStringAsFixed(0)}',
          deepLink: '/inventory/stock/${j['product_id']}',
        );
      case DrilldownType.account:
        final dr = num(j['debit']);
        final cr = num(j['credit']);
        return DrilldownRow(
          title: j['entry_number']?.toString() ?? '—',
          subtitle:
              (j['narration'] ?? j['description'] ?? '').toString(),
          trailing: dr > 0 ? 'Dr ${formatPkr(dr)}' : 'Cr ${formatPkr(cr)}',
          deepLink: '/accounting/journal/${j['journal_entry_id']}',
        );
      case DrilldownType.product:
        return DrilldownRow(
          title: j['invoice_number']?.toString() ?? '—',
          subtitle:
              '${num(j['qty']).toStringAsFixed(0)} × ${formatPkr(num(j['unit_price']))}',
          trailing: formatPkr(num(j['line_total'])),
          deepLink: '/sales/invoice/${j['invoice_number']}',
        );
    }
  }
}
