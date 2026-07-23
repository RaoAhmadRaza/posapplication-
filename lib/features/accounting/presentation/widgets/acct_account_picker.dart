import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_search_field.dart';
import '../../../../core/design/widgets/app_sheet.dart';
import '../../domain/entities/account.dart';
import 'accounting_ui.dart';

/// Searchable account picker sheet, shared by the voucher line editor and the
/// bank-reconciliation adjustment field. Returns the chosen [Account] or null.
Future<Account?> showAccountPicker(
  BuildContext context,
  List<Account> accounts, {
  String title = 'Select account',
}) {
  final sorted = [...accounts]..sort((a, b) => a.code.compareTo(b.code));
  return showAppSheet<Account>(
    context: context,
    builder: (ctx) => _AccountPickerSheet(accounts: sorted, title: title),
  );
}

class _AccountPickerSheet extends StatefulWidget {
  const _AccountPickerSheet({required this.accounts, required this.title});
  final List<Account> accounts;
  final String title;

  @override
  State<_AccountPickerSheet> createState() => _AccountPickerSheetState();
}

class _AccountPickerSheetState extends State<_AccountPickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(
        () => setState(() => _query = _search.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final visible = _query.isEmpty
        ? widget.accounts
        : widget.accounts
            .where((a) =>
                a.code.toLowerCase().contains(_query) ||
                a.name.toLowerCase().contains(_query))
            .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title,
            style: AppTypography.title3.copyWith(color: lum.textPrimary)),
        const SizedBox(height: 12),
        AppSearchField(
          controller: _search,
          hint: 'Search accounts',
          onClear: () => setState(() => _query = ''),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: visible.length,
            itemBuilder: (_, i) {
              final a = visible[i];
              return Semantics(
                button: true,
                label: '${a.code} ${a.name}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(a),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: lum.hairline)),
                    ),
                    child: Row(
                      children: [
                        AcctCodeChip(a.code),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(a.name,
                              style: AppTypography.subhead
                                  .copyWith(color: lum.textPrimary)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
