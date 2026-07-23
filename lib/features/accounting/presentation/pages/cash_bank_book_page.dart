import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../controllers/reports_controller.dart';
import '../widgets/acct_date_field.dart';
import '../widgets/acct_ledger_table.dart';
import '../widgets/report_filters.dart';

const _accounts = <String, String>{'1000': 'Cash', '1010': 'Bank'};

class CashBankBookPage extends ConsumerStatefulWidget {
  const CashBankBookPage({super.key});

  @override
  ConsumerState<CashBankBookPage> createState() => _CashBankBookPageState();
}

class _CashBankBookPageState extends ConsumerState<CashBankBookPage> {
  String _accountCode = '1000';
  late DateTime _from;
  DateTime _to = DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(cashBankBookProvider(
        (accountCode: _accountCode, from: _from, to: _to)));

    return AppDetailScaffold(
      eyebrow: 'Accounting',
      title: 'Cash & bank book',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              _AccountChip(
                  value: _accountCode,
                  onChanged: (v) => setState(() => _accountCode = v)),
              ReportDateChip(
                  label: 'From',
                  value: _from,
                  onPick: (d) => setState(() => _from = d)),
              ReportDateChip(
                  label: 'To',
                  value: _to,
                  onPick: (d) => setState(() => _to = d)),
            ],
          ),
          const SizedBox(height: 14),
          book.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 50),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 30),
              child: AppErrorState(
                title: 'Couldn\'t load report',
                body: 'Your data is safe. Check the connection and try again.',
                onRetry: () => ref.invalidate(cashBankBookProvider(
                    (accountCode: _accountCode, from: _from, to: _to))),
              ),
            ),
            data: (b) => AcctLedgerCard(
              openingBalance: b.openingBalance,
              inOut: true,
              rows: [
                for (final e in b.entries)
                  AcctLedgerRow(
                    date: e.date == null ? '—' : acctFormatDateShort(e.date!),
                    particulars: e.description ?? e.entryNumber ?? 'Entry',
                    debit: e.debit,
                    credit: e.credit,
                    balance: e.runningBalance,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact clay account chip (Cash / Bank), matching the report filter chips.
class _AccountChip extends StatelessWidget {
  const _AccountChip({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return ClayContainer(
      variant: ClayVariant.soft,
      color: lum.surface,
      borderRadius: AppRadius.pill,
      isDark: lum.isDark,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(AppRadius.md),
          dropdownColor: lum.surface,
          icon: Icon(LucideIcons.chevronDown, size: 15, color: lum.g500),
          style: AppTypography.subhead.copyWith(color: lum.textPrimary),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          items: [
            for (final e in _accounts.entries)
              DropdownMenuItem(
                value: e.key,
                child: Text('${e.value} · ${e.key}'),
              ),
          ],
        ),
      ),
    );
  }
}
