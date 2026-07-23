import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_dropdown.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../controllers/bank_accounts_controller.dart';
import '../controllers/expenses_controller.dart';
import '../widgets/acct_date_field.dart';
import '../widgets/accounting_ui.dart';

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
      setState(() => _saving = false);
      showAppToast(context, failure.message, type: BannerType.error);
      return;
    }
    showAppToast(context, 'Expense recorded', type: BannerType.success);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(expenseCategoriesProvider).value ?? const [];
    final banks = ref.watch(bankAccountsProvider).value ?? const [];

    return AppDetailScaffold(
      eyebrow: 'Accounting',
      title: 'Record expense',
      maxContentWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AppInlineBanner(message: _error!, type: BannerType.error),
            const SizedBox(height: 16),
          ],
          AppCard(
            child: _FieldsGrid(
              children: [
                _Labeled(
                  'Category',
                  AppDropdown<String>(
                    value: _categoryId,
                    placeholder: 'Select category',
                    options: [
                      for (final c in categories)
                        AppDropdownOption(value: c.id, label: c.name),
                    ],
                    onSelected: (v) => setState(() => _categoryId = v),
                  ),
                ),
                _Labeled(
                  'Date',
                  AcctDateField(
                    value: _date,
                    onChanged: (v) {
                      if (v != null) setState(() => _date = v);
                    },
                  ),
                ),
                AppTextField(
                  controller: _amount,
                  label: 'Amount',
                  prefixIcon: LucideIcons.banknote,
                  hint: '0',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                AppTextField(
                  controller: _tax,
                  label: 'Tax amount',
                  prefixIcon: LucideIcons.percent,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                _Labeled(
                  'Payment method',
                  AppDropdown<String>(
                    value: _method,
                    options: [
                      for (final e in _paymentMethods.entries)
                        AppDropdownOption(value: e.key, label: e.value),
                    ],
                    onSelected: (v) => setState(() => _method = v),
                  ),
                ),
                _Labeled(
                  'Bank account',
                  AppDropdown<String>(
                    value: _bankAccountId,
                    placeholder: 'Select account',
                    options: [
                      for (final b in banks)
                        AppDropdownOption(
                            value: b.id, label: b.accountName),
                    ],
                    onSelected: (v) => setState(() => _bankAccountId = v),
                  ),
                ),
                AppTextField(
                  controller: _reference,
                  label: 'Reference',
                  prefixIcon: LucideIcons.hash,
                  hint: 'Optional',
                ),
                AppTextField(
                  controller: _description,
                  label: 'Description',
                  prefixIcon: LucideIcons.pencil,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _Actions(
            onManage: () => context.push('/accounting/expense-categories'),
            submit: PermissionGate(
              module: 'accounting',
              action: 'create',
              child: AppButton(
                label: 'Record expense',
                variant: AppButtonVariant.filled,
                icon: LucideIcons.check,
                loading: _saving,
                fullWidth: true,
                onPressed: _submit,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two columns on a wide card, one on a narrow one — no fixed aspect ratio,
/// each cell keeps its control's natural height.
class _FieldsGrid extends StatelessWidget {
  const _FieldsGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const gap = 16.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCol = constraints.maxWidth >= 460;
        final width =
            twoCol ? (constraints.maxWidth - gap) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

/// A section label stacked above a control that carries no label of its own.
class _Labeled extends StatelessWidget {
  const _Labeled(this.label, this.child);

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AcctSectionLabel(label),
        const SizedBox(height: 7),
        child,
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onManage, required this.submit});

  final VoidCallback onManage;
  final Widget submit;

  @override
  Widget build(BuildContext context) {
    final manage = AppButton(
      label: 'Manage categories',
      variant: AppButtonVariant.tinted,
      icon: LucideIcons.settings2,
      onPressed: onManage,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 460) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              submit,
              const SizedBox(height: 12),
              AppButton(
                label: 'Manage categories',
                variant: AppButtonVariant.tinted,
                icon: LucideIcons.settings2,
                fullWidth: true,
                onPressed: onManage,
              ),
            ],
          );
        }
        return Row(
          children: [
            manage,
            const Spacer(),
            submit,
          ],
        );
      },
    );
  }
}
