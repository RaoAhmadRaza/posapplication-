import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/expense_category.dart';
import '../controllers/chart_of_accounts_controller.dart';
import '../controllers/expenses_controller.dart';

class ExpenseCategoriesPage extends ConsumerWidget {
  const ExpenseCategoriesPage({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final accounts = (ref.read(chartOfAccountsProvider).value ?? const [])
        .where((a) => a.type == AccountType.expense)
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    final result = await showDialog<_NewCategory>(
      context: context,
      builder: (_) => _AddCategoryDialog(accounts: accounts),
    );
    if (result == null) return;
    final failure =
        await ref.read(expensesProvider.notifier).createCategory(
              name: result.name,
              accountId: result.accountId,
            );
    if (!context.mounted) return;
    if (failure != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message)));
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Category added')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(expenseCategoriesProvider);

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
        title: Text('Expense Categories', style: AppTypography.headline),
      ),
      floatingActionButton: PermissionGate(
        module: 'accounting',
        action: 'create',
        child: FloatingActionButton(
          backgroundColor: AppColors.accent,
          onPressed: () => _add(context, ref),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding),
              child: AppInlineBanner(
                  message: 'Could not load categories.',
                  type: BannerType.error),
            ),
          ),
          data: (categories) => categories.isEmpty
              ? Center(
                  child: Text('No categories yet',
                      style: AppTypography.subhead
                          .copyWith(color: AppColors.textMuted)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPadding,
                      vertical: AppSpacing.md),
                  itemCount: categories.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => _CategoryTile(category: categories[i]),
                ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});
  final ExpenseCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.separator),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder, size: 18, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
              child: Text(category.name, style: AppTypography.subhead)),
          if (!category.isActive)
            Text('Inactive',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textHint)),
        ],
      ),
    );
  }
}

class _NewCategory {
  const _NewCategory({required this.name, required this.accountId});
  final String name;
  final String accountId;
}

class _AddCategoryDialog extends StatefulWidget {
  const _AddCategoryDialog({required this.accounts});
  final List<Account> accounts;

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final _name = TextEditingController();
  String? _accountId;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    final accountId = _accountId;
    if (accountId == null) {
      setState(() => _error = 'Select an account.');
      return;
    }
    Navigator.of(context).pop(_NewCategory(name: name, accountId: accountId));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.background,
      title: Text('New Category', style: AppTypography.headline),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            AppInlineBanner(message: _error!, type: BannerType.error),
            const SizedBox(height: AppSpacing.md),
          ],
          AppTextField(
            controller: _name,
            label: 'Name',
            prefixIcon: Icons.folder,
          ),
          const SizedBox(height: AppSpacing.fieldGap),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.field),
              border: Border.all(color: AppColors.separator),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _accountId,
                isExpanded: true,
                hint: Text('Expense account',
                    style: AppTypography.subhead
                        .copyWith(color: AppColors.textHint)),
                icon: const Icon(Icons.keyboard_arrow_down,
                    size: 18, color: AppColors.textMuted),
                style: AppTypography.subhead,
                onChanged: (v) => setState(() => _accountId = v),
                items: widget.accounts
                    .map((a) => DropdownMenuItem(
                        value: a.id,
                        child: Text('${a.code}  ${a.name}',
                            overflow: TextOverflow.ellipsis)))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _save, child: const Text('Add')),
      ],
    );
  }
}
