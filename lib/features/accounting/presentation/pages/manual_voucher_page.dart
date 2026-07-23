import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_dropdown.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/voucher.dart';
import '../controllers/chart_of_accounts_controller.dart';
import '../controllers/vouchers_controller.dart';
import '../widgets/acct_account_picker.dart';
import '../widgets/accounting_ui.dart';

const _voucherLabels = <VoucherType, String>{
  VoucherType.payment: 'Payment',
  VoucherType.receipt: 'Receipt',
  VoucherType.contra: 'Contra',
  VoucherType.journal: 'Journal',
};

class _LineDraft {
  _LineDraft();
  String? accountId;
  String? accountCode;
  final debit = TextEditingController();
  final credit = TextEditingController();

  void dispose() {
    debit.dispose();
    credit.dispose();
  }
}

class ManualVoucherPage extends ConsumerStatefulWidget {
  const ManualVoucherPage({super.key});

  @override
  ConsumerState<ManualVoucherPage> createState() => _ManualVoucherPageState();
}

class _ManualVoucherPageState extends ConsumerState<ManualVoucherPage> {
  final _description = TextEditingController();
  final _reference = TextEditingController();
  VoucherType _type = VoucherType.journal;
  final _lines = <_LineDraft>[_LineDraft(), _LineDraft()];

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    _reference.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double _sum(bool debit) {
    var total = 0.0;
    for (final l in _lines) {
      total += double.tryParse((debit ? l.debit : l.credit).text.trim()) ?? 0;
    }
    return total;
  }

  bool get _balanced {
    final d = _sum(true);
    final c = _sum(false);
    return d > 0 && (d - c).abs() < 0.005;
  }

  void _addLine() => setState(() => _lines.add(_LineDraft()));

  void _removeLine(int i) {
    if (_lines.length <= 2) return;
    setState(() {
      _lines.removeAt(i).dispose();
    });
  }

  Future<void> _submit() async {
    final branch = ref.read(currentBranchProvider);
    if (branch == null) {
      setState(() => _error = 'Select a branch first.');
      return;
    }
    final description = _description.text.trim();
    if (description.isEmpty) {
      setState(() => _error = 'Description is required.');
      return;
    }
    final lines = <Map<String, dynamic>>[];
    for (final l in _lines) {
      final code = l.accountCode;
      if (code == null) {
        setState(() => _error = 'Every line needs an account.');
        return;
      }
      final debit = double.tryParse(l.debit.text.trim()) ?? 0;
      final credit = double.tryParse(l.credit.text.trim()) ?? 0;
      lines.add({'account_code': code, 'debit': debit, 'credit': credit});
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final reference = _reference.text.trim();
    final failure =
        await ref.read(voucherControllerProvider.notifier).createVoucher(
              branchId: branch.id,
              type: _type,
              amount: _sum(true),
              reference: reference.isEmpty ? null : reference,
              description: description,
              lines: lines,
            );

    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _saving = false;
        _error = failure.message;
      });
      return;
    }
    showAppToast(context, 'Voucher posted', type: BannerType.success);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(chartOfAccountsProvider).value ?? const [];
    final totalDebit = _sum(true);
    final totalCredit = _sum(false);

    return AppDetailScaffold(
      eyebrow: 'Accounting',
      title: 'New voucher',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AppInlineBanner(message: _error!, type: BannerType.error),
            const SizedBox(height: 14),
          ],
          AppCard(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 520;
                final type = _LabeledField(
                  label: 'Voucher type',
                  child: AppDropdown<VoucherType>(
                    value: _type,
                    onSelected: (t) => setState(() => _type = t),
                    options: [
                      for (final t in VoucherType.values)
                        AppDropdownOption(
                            value: t, label: _voucherLabels[t] ?? t.name),
                    ],
                  ),
                );
                final reference = _LabeledField(
                  label: 'Reference',
                  child: AppTextField(
                    controller: _reference,
                    label: '',
                    prefixIcon: LucideIcons.hash,
                    hint: 'Optional',
                  ),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: type),
                          const SizedBox(width: 14),
                          Expanded(child: reference),
                        ],
                      )
                    else ...[
                      type,
                      const SizedBox(height: 14),
                      reference,
                    ],
                    const SizedBox(height: 14),
                    _LabeledField(
                      label: 'Description',
                      child: AppTextField(
                        controller: _description,
                        label: '',
                        prefixIcon: LucideIcons.pencil,
                        hint: 'What is this voucher for?',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AcctSectionLabel('Lines'),
                const SizedBox(height: 12),
                for (var i = 0; i < _lines.length; i++) ...[
                  _LineEditor(
                    line: _lines[i],
                    accounts: accounts,
                    canRemove: _lines.length > 2,
                    onChanged: () => setState(() {}),
                    onPickAccount: (a) => setState(() {
                      _lines[i].accountId = a.id;
                      _lines[i].accountCode = a.code;
                    }),
                    onRemove: () => _removeLine(i),
                  ),
                  const SizedBox(height: 10),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppButton(
                    label: 'Add line',
                    variant: AppButtonVariant.plain,
                    size: AppButtonSize.sm,
                    icon: LucideIcons.plus,
                    onPressed: _addLine,
                  ),
                ),
                const SizedBox(height: 10),
                _BalanceStrip(debit: totalDebit, credit: totalCredit),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PermissionGate(
            module: 'accounting',
            action: 'create',
            child: AppButton(
              label: 'Post voucher',
              loading: _saving,
              fullWidth: true,
              icon: LucideIcons.check,
              onPressed: _balanced ? _submit : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Text(
            label,
            style: AppTypography.subhead.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: lum.g700,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _LineEditor extends StatelessWidget {
  const _LineEditor({
    required this.line,
    required this.accounts,
    required this.canRemove,
    required this.onChanged,
    required this.onPickAccount,
    required this.onRemove,
  });

  final _LineDraft line;
  final List<Account> accounts;
  final bool canRemove;
  final VoidCallback onChanged;
  final ValueChanged<Account> onPickAccount;
  final VoidCallback onRemove;

  Future<void> _pick(BuildContext context) async {
    final account = await showAccountPicker(context, accounts);
    if (account != null) onPickAccount(account);
  }

  String _nameFor(String? id) {
    for (final a in accounts) {
      if (a.id == id) return a.name;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final hasAccount = line.accountCode != null;
    final label = hasAccount
        ? '${line.accountCode} · ${_nameFor(line.accountId)}'
        : 'Select account';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: lum.surface2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: lum.hairline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: label,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _pick(context),
                    child: Row(
                      children: [
                        Icon(LucideIcons.listTree, size: 17, color: lum.g500),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            label,
                            style: AppTypography.subhead.copyWith(
                              color:
                                  hasAccount ? lum.textPrimary : lum.textTertiary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(LucideIcons.chevronDown, size: 15, color: lum.g400),
                      ],
                    ),
                  ),
                ),
              ),
              if (canRemove)
                Semantics(
                  button: true,
                  label: 'Remove line',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onRemove,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(LucideIcons.x, size: 16),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _AmountField(
                    controller: line.debit, hint: 'Debit', onChanged: onChanged),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AmountField(
                    controller: line.credit,
                    hint: 'Credit',
                    onChanged: onChanged),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });
  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return ClayContainer(
      variant: ClayVariant.inset,
      color: lum.surface,
      borderRadius: AppRadius.md,
      isDark: lum.isDark,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Center(
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.right,
          style: TextStyle(
            fontFamily: AppTypography.mono,
            fontSize: 14,
            color: lum.textPrimary,
          ),
          cursorColor: lum.accent,
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            isCollapsed: true,
            filled: false,
            border: InputBorder.none,
            hintText: hint,
            hintStyle: AppTypography.subhead.copyWith(color: lum.textTertiary),
          ),
        ),
      ),
    );
  }
}

class _BalanceStrip extends StatelessWidget {
  const _BalanceStrip({required this.debit, required this.credit});
  final double debit;
  final double credit;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final balanced = debit > 0 && (debit - credit).abs() < 0.005;
    final diff = (debit - credit).abs();
    final bg = balanced ? lum.successSoft : lum.dangerSoft;
    final fg = balanced ? lum.successText : lum.dangerText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            balanced ? LucideIcons.circleCheckBig : LucideIcons.triangleAlert,
            size: 17,
            color: fg,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              balanced
                  ? 'Balanced'
                  : 'Unbalanced · off by ${formatAmount(diff, decimals: 0)}',
              style: AppTypography.subhead
                  .copyWith(fontWeight: FontWeight.w700, color: fg),
            ),
          ),
          AcctMono(formatAmount(debit, decimals: 0), color: fg, size: 13),
          const SizedBox(width: 14),
          AcctMono(formatAmount(credit, decimals: 0), color: fg, size: 13),
        ],
      ),
    );
  }
}
