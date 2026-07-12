import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/bank_account.dart';
import '../../domain/entities/expense_category.dart';
import '../controllers/bank_accounts_controller.dart';
import '../controllers/expenses_controller.dart';

const _paymentMethods = <String, String>{
  'CASH': 'Cash',
  'BANK_TRANSFER': 'Bank Transfer',
  'CARD': 'Card',
  'MOBILE_WALLET': 'Mobile Wallet',
  'CHEQUE': 'Cheque',
};

class ExpenseFormPage extends ConsumerStatefulWidget {
  const ExpenseFormPage({super.key});

  @override
  ConsumerState<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends ConsumerState<ExpenseFormPage> {
  final _amount = TextEditingController();
  final _tax = TextEditingController(text: '0');
  final _reference = TextEditingController();
  final _description = TextEditingController();
  String? _categoryId;
  String _method = 'CASH';
  String? _bankAccountId;
  DateTime _date = DateTime.now();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _tax.dispose();
    _reference.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final branch = ref.read(currentBranchProvider);
    if (branch == null) {
      setState(() => _error = 'Select a branch first.');
      return;
    }
    final categoryId = _categoryId;
    if (categoryId == null) {
      setState(() => _error = 'Select a category.');
      return;
    }
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    final tax = double.tryParse(_tax.text.trim()) ?? 0;
    final description = _description.text.trim();
    if (description.isEmpty) {
      setState(() => _error = 'Description is required.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final reference = _reference.text.trim();
    final failure =
        await ref.read(expensesProvider.notifier).createExpense(
              branchId: branch.id,
              categoryId: categoryId,
              amount: amount,
              taxAmount: tax,
              expenseDate: _date,
              paymentMethod: _method,
              bankAccountId: _method == 'CASH' ? null : _bankAccountId,
              reference: reference.isEmpty ? null : reference,
              description: description,
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
        .showSnackBar(const SnackBar(content: Text('Expense recorded')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(expenseCategoriesProvider).value ?? const [];
    final banks = ref.watch(bankAccountsProvider).value ?? const [];

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
        title: Text('New Expense', style: AppTypography.headline),
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
                    _group('Category'),
                    _CategoryDropdown(
                      value: _categoryId,
                      categories: categories,
                      onChanged: (v) => setState(() => _categoryId = v),
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    AppTextField(
                      controller: _amount,
                      label: 'Amount',
                      prefixIcon: Icons.attach_money,
                      hint: '0',
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    AppTextField(
                      controller: _tax,
                      label: 'Tax Amount',
                      prefixIcon: Icons.percent,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    _group('Date'),
                    _DateTile(date: _date, onTap: _pickDate),
                    const SizedBox(height: AppSpacing.fieldGap),
                    _group('Payment Method'),
                    _MethodDropdown(
                      value: _method,
                      onChanged: (m) => setState(() => _method = m),
                    ),
                    if (_method != 'CASH') ...[
                      const SizedBox(height: AppSpacing.fieldGap),
                      _group('Bank Account'),
                      _BankDropdown(
                        value: _bankAccountId,
                        banks: banks,
                        onChanged: (v) =>
                            setState(() => _bankAccountId = v),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.fieldGap),
                    AppTextField(
                      controller: _reference,
                      label: 'Reference',
                      prefixIcon: Icons.tag,
                      hint: 'Optional',
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    AppTextField(
                      controller: _description,
                      label: 'Description',
                      prefixIcon: Icons.notes,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppButton(
                        label: 'Manage Categories',
                        variant: AppButtonVariant.plain,
                        icon: Icons.settings,
                        onPressed: () =>
                            context.push('/accounting/expense-categories'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PermissionGate(
                      module: 'accounting',
                      action: 'create',
                      child: AppButton(
                        label: 'Record Expense',
                        loading: _saving,
                        fullWidth: true,
                        icon: Icons.check,
                        onPressed: _submit,
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

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.value,
    required this.categories,
    required this.onChanged,
  });
  final String? value;
  final List<ExpenseCategory> categories;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _DropdownShell(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        hint: Text('Select category',
            style: AppTypography.subhead
                .copyWith(color: AppColors.textHint)),
        icon: const Icon(Icons.keyboard_arrow_down,
            size: 18, color: AppColors.textMuted),
        style: AppTypography.subhead,
        onChanged: onChanged,
        items: categories
            .map((c) =>
                DropdownMenuItem(value: c.id, child: Text(c.name)))
            .toList(),
      ),
    );
  }
}

class _MethodDropdown extends StatelessWidget {
  const _MethodDropdown({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _DropdownShell(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down,
            size: 18, color: AppColors.textMuted),
        style: AppTypography.subhead,
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        items: _paymentMethods.entries
            .map((e) =>
                DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
      ),
    );
  }
}

class _BankDropdown extends StatelessWidget {
  const _BankDropdown({
    required this.value,
    required this.banks,
    required this.onChanged,
  });
  final String? value;
  final List<BankAccount> banks;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _DropdownShell(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        hint: Text('Select account',
            style: AppTypography.subhead
                .copyWith(color: AppColors.textHint)),
        icon: const Icon(Icons.keyboard_arrow_down,
            size: 18, color: AppColors.textMuted),
        style: AppTypography.subhead,
        onChanged: onChanged,
        items: banks
            .map((b) => DropdownMenuItem(
                value: b.id, child: Text(b.accountName)))
            .toList(),
      ),
    );
  }
}

class _DropdownShell extends StatelessWidget {
  const _DropdownShell({required this.child});
  final Widget child;

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
      child: DropdownButtonHideUnderline(child: child),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.date, required this.onTap});
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = '${date.year}-${date.month.toString().padLeft(2, '0')}'
        '-${date.day.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(AppRadius.field),
          border: Border.all(color: AppColors.separator),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                size: 18, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: AppTypography.subhead)),
            const Icon(Icons.chevron_right,
                size: 20, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
