import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_dropdown.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_sheet.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/expense_category.dart';
import '../controllers/chart_of_accounts_controller.dart';
import '../controllers/expenses_controller.dart';
import '../widgets/accounting_ui.dart';

class ExpenseCategoriesPage extends ConsumerWidget {
  const ExpenseCategoriesPage({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final accounts = (ref.read(chartOfAccountsProvider).value ?? const [])
        .where((a) => a.type == AccountType.expense)
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    final result = await showAppSheet<_NewCategory>(
      context: context,
      builder: (_) => _AddCategorySheet(accounts: accounts),
    );
    if (result == null) return;
    final failure = await ref.read(expensesProvider.notifier).createCategory(
          name: result.name,
          accountId: result.accountId,
        );
    if (!context.mounted) return;
    if (failure != null) {
      showAppToast(context, failure.message, type: BannerType.error);
      return;
    }
    showAppToast(context, 'Category added', type: BannerType.success);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(expenseCategoriesProvider);

    return AppDetailScaffold(
      eyebrow: 'Accounting',
      title: 'Expense categories',
      actions: [
        PermissionGate(
          module: 'accounting',
          action: 'create',
          child: AppButton(
            label: 'New category',
            size: AppButtonSize.sm,
            icon: LucideIcons.plus,
            onPressed: () => _add(context, ref),
          ),
        ),
      ],
      child: state.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => AppErrorState(
          title: "Couldn't load categories",
          body: 'Your data is safe. Check the connection and try again.',
          onRetry: () =>
              ref.read(expenseCategoriesProvider.notifier).refresh(),
        ),
        data: (categories) => categories.isEmpty
            ? const AppEmptyState(
                icon: LucideIcons.tag,
                title: 'No categories yet',
                body: 'Add a category to organise your expenses.',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < categories.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                          bottom: i < categories.length - 1 ? 12 : 0),
                      child: _CategoryCard(category: categories[i]),
                    ),
                ],
              ),
      ),
    );
  }
}

class _CategoryCard extends ConsumerWidget {
  const _CategoryCard({required this.category});
  final ExpenseCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final accounts = ref.watch(chartOfAccountsProvider).value ?? const [];
    final matches = accounts.where((a) => a.id == category.accountId);
    final account = matches.isEmpty ? null : matches.first;
    final accountLabel =
        account == null ? '—' : '${account.code} · ${account.name}';

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          AcctIconTile(
            icon: LucideIcons.tag,
            background: lum.surface2,
            foreground: lum.g600,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: AppTypography.headline.copyWith(fontSize: 14.5),
                ),
                const SizedBox(height: 2),
                Text(
                  accountLabel,
                  style: AppTypography.subhead
                      .copyWith(fontSize: 12.5, color: lum.g500),
                ),
              ],
            ),
          ),
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

class _AddCategorySheet extends StatefulWidget {
  const _AddCategorySheet({required this.accounts});
  final List<Account> accounts;

  @override
  State<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<_AddCategorySheet> {
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSheetHeader(title: 'New category'),
        AppTextField(
          controller: _name,
          label: 'Name',
          prefixIcon: LucideIcons.tag,
        ),
        const SizedBox(height: 16),
        AppDropdown<String>(
          value: _accountId,
          placeholder: 'Expense account',
          options: [
            for (final a in widget.accounts)
              AppDropdownOption(value: a.id, label: '${a.code} · ${a.name}'),
          ],
          onSelected: (v) => setState(() => _accountId = v),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          AppInlineBanner(message: _error!, type: BannerType.error),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.tinted,
                fullWidth: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                label: 'Add',
                fullWidth: true,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
