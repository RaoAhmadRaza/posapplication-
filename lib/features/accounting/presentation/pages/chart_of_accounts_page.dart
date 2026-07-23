import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_search_field.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../domain/entities/account.dart';
import '../controllers/chart_of_accounts_controller.dart';
import '../widgets/accounting_ui.dart';

const _typeLabels = <AccountType, String>{
  AccountType.asset: 'Assets',
  AccountType.liability: 'Liabilities',
  AccountType.equity: 'Equity',
  AccountType.revenue: 'Revenue',
  AccountType.expense: 'Expenses',
};

class ChartOfAccountsPage extends ConsumerStatefulWidget {
  const ChartOfAccountsPage({super.key});

  @override
  ConsumerState<ChartOfAccountsPage> createState() =>
      _ChartOfAccountsPageState();
}

class _ChartOfAccountsPageState extends ConsumerState<ChartOfAccountsPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(
      () => setState(() => _query = _search.text.trim()),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Account a) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return a.code.toLowerCase().contains(q) ||
        a.name.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chartOfAccountsProvider);

    return AppDetailScaffold(
      eyebrow: 'Accounting',
      title: 'Chart of accounts',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSearchField(
            controller: _search,
            hint: 'Search by code or name',
            onClear: () => setState(() => _query = ''),
          ),
          const SizedBox(height: 14),
          state.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 40),
              child: AppErrorState(
                title: 'Couldn\'t load accounts',
                body: 'Your data is safe. Check the connection and try again.',
                onRetry: () =>
                    ref.read(chartOfAccountsProvider.notifier).refresh(),
              ),
            ),
            data: (accounts) {
              final visible = accounts.where(_matches).toList();
              final cards = <Widget>[];
              for (final type in AccountType.values) {
                final card = _TypeCard(
                  type: type,
                  all: accounts,
                  visible: visible,
                  expanded: _query.isNotEmpty,
                );
                cards.add(card);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final c in cards) ...[
                    c,
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TypeCard extends StatefulWidget {
  const _TypeCard({
    required this.type,
    required this.all,
    required this.visible,
    required this.expanded,
  });

  final AccountType type;
  final List<Account> all;
  final List<Account> visible;
  final bool expanded;

  @override
  State<_TypeCard> createState() => _TypeCardState();
}

class _TypeCardState extends State<_TypeCard> {
  late bool _open = widget.expanded;

  @override
  void didUpdateWidget(_TypeCard old) {
    super.didUpdateWidget(old);
    // A live search should force the matched groups open.
    if (widget.expanded && !old.expanded) _open = true;
  }

  List<Account> get _topLevel {
    final roots = widget.visible
        .where((a) => a.type == widget.type && a.parentId == null)
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    final rootIds = roots.map((a) => a.id).toSet();
    final orphans = widget.visible
        .where((a) =>
            a.type == widget.type &&
            a.parentId != null &&
            !rootIds.contains(a.parentId))
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    return [...roots, ...orphans];
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final topLevel = _topLevel;
    if (topLevel.isEmpty) return const SizedBox.shrink();

    final rows = <Account>[];
    for (final account in topLevel) {
      rows.add(account);
      rows.addAll(widget.all
          .where((c) => c.parentId == account.id)
          .toList()
        ..sort((a, b) => a.code.compareTo(b.code)));
    }
    final total = rows.fold<double>(0, (s, a) => s + a.currentBalance);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label: _typeLabels[widget.type] ?? widget.type.name,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _open = !_open),
              child: Container(
                decoration: BoxDecoration(
                  color: lum.surface2,
                  border: Border(bottom: BorderSide(color: lum.hairline)),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    Icon(
                      _open ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                      size: 18,
                      color: lum.g500,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _typeLabels[widget.type] ?? widget.type.name,
                      style: AppTypography.subhead.copyWith(
                        fontWeight: FontWeight.w700,
                        color: lum.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: lum.g100,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${rows.length}',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: lum.g600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    AppMoneyText(total, size: 14),
                  ],
                ),
              ),
            ),
          ),
          if (_open)
            for (final account in rows) _AccountRow(account: account),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final isChild = account.parentId != null;
    return Semantics(
      button: true,
      label: '${account.code} ${account.name}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/accounting/accounts/${account.id}/ledger'),
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: lum.hairline)),
          ),
          padding: EdgeInsets.only(
            left: isChild ? 30 : 16,
            right: 16,
            top: 13,
            bottom: 13,
          ),
          child: Row(
            children: [
              AcctCodeChip(account.code),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  account.name,
                  style: AppTypography.subhead
                      .copyWith(fontSize: 14, color: lum.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              AppMoneyText(account.currentBalance, size: 13.5),
              const SizedBox(width: 6),
              Icon(LucideIcons.chevronRight, size: 16, color: lum.g400),
            ],
          ),
        ),
      ),
    );
  }
}
