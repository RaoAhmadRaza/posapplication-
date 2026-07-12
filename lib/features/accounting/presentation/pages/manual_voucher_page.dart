import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/voucher.dart';
import '../controllers/chart_of_accounts_controller.dart';
import '../controllers/vouchers_controller.dart';

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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Voucher created')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(chartOfAccountsProvider).value ?? const [];
    final totalDebit = _sum(true);
    final totalCredit = _sum(false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Manual Voucher', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    if (_error != null) ...[
                      AppInlineBanner(
                          message: _error!, type: BannerType.error),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    _group('Type'),
                    _TypeDropdown(
                      value: _type,
                      onChanged: (t) => setState(() => _type = t),
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    AppTextField(
                      controller: _description,
                      label: 'Description',
                      prefixIcon: Icons.notes,
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    AppTextField(
                      controller: _reference,
                      label: 'Reference',
                      prefixIcon: Icons.tag,
                      hint: 'Optional',
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _group('Lines'),
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
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppButton(
                        label: 'Add Line',
                        variant: AppButtonVariant.tinted,
                        icon: Icons.add,
                        onPressed: _addLine,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _Totals(debit: totalDebit, credit: totalCredit),
                    const SizedBox(height: AppSpacing.xl),
                    PermissionGate(
                      module: 'accounting',
                      action: 'create',
                      child: AppButton(
                        label: 'Post Voucher',
                        loading: _saving,
                        fullWidth: true,
                        icon: Icons.check,
                        onPressed: _balanced ? _submit : null,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _group(String label) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(label.toUpperCase(),
            style: AppTypography.footnote.copyWith(
                color: AppColors.textMuted, fontWeight: FontWeight.w600)),
      );
}

class _TypeDropdown extends StatelessWidget {
  const _TypeDropdown({required this.value, required this.onChanged});
  final VoucherType value;
  final ValueChanged<VoucherType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.separator),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<VoucherType>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down,
              size: 18, color: AppColors.textMuted),
          style: AppTypography.subhead,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          items: VoucherType.values
              .map((t) => DropdownMenuItem(
                  value: t, child: Text(_voucherLabels[t] ?? t.name)))
              .toList(),
        ),
      ),
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
    final account = await _showAccountPicker(context, accounts);
    if (account != null) onPickAccount(account);
  }

  @override
  Widget build(BuildContext context) {
    final label = line.accountCode == null
        ? 'Select account'
        : '${line.accountCode}  ${_nameFor(line.accountId)}';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.separator),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pick(context),
                  child: Row(
                    children: [
                      const Icon(Icons.account_tree,
                          size: 18, color: AppColors.textMuted),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(label,
                            style: AppTypography.subhead,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              ),
              if (canRemove)
                IconButton(
                  icon: const Icon(Icons.close,
                      size: 18, color: AppColors.destructive),
                  onPressed: onRemove,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _AmountField(
                  controller: line.debit,
                  hint: 'Debit',
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _AmountField(
                  controller: line.credit,
                  hint: 'Credit',
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _nameFor(String? id) {
    for (final a in accounts) {
      if (a.id == id) return a.name;
    }
    return '';
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
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.separator),
      ),
      child: TextField(
        controller: controller,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        style: AppTypography.subhead,
        cursorColor: AppColors.accent,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: AppTypography.subhead
              .copyWith(color: AppColors.textHint),
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.debit, required this.credit});
  final double debit;
  final double credit;

  @override
  Widget build(BuildContext context) {
    final balanced = debit > 0 && (debit - credit).abs() < 0.005;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Debit', style: AppTypography.footnote),
              Text(formatPkr(debit), style: AppTypography.subhead),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Credit', style: AppTypography.footnote),
              Text(formatPkr(credit), style: AppTypography.subhead),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(balanced ? Icons.check_circle : Icons.error_outline,
                  size: 16,
                  color:
                      balanced ? AppColors.success : AppColors.warning),
              const SizedBox(width: AppSpacing.xs),
              Text(balanced ? 'Balanced' : 'Debits must equal credits',
                  style: AppTypography.caption.copyWith(
                      color: balanced
                          ? AppColors.success
                          : AppColors.warning)),
            ],
          ),
        ],
      ),
    );
  }
}

Future<Account?> _showAccountPicker(
    BuildContext context, List<Account> accounts) {
  final sorted = [...accounts]..sort((a, b) => a.code.compareTo(b.code));
  return showModalBottomSheet<Account>(
    context: context,
    backgroundColor: AppColors.background,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          itemCount: sorted.length,
          itemBuilder: (_, i) {
            final a = sorted[i];
            return ListTile(
              title: Text('${a.code}  ${a.name}',
                  style: AppTypography.subhead),
              onTap: () => Navigator.of(ctx).pop(a),
            );
          },
        ),
      ),
    ),
  );
}
