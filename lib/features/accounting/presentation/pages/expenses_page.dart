import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/expense.dart';
import '../controllers/expenses_controller.dart';
import '../widgets/acct_date_field.dart';
import '../widgets/accounting_ui.dart';

class ExpensesPage extends ConsumerWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(expensesProvider);
    final categories = ref.watch(expenseCategoriesProvider).value ?? const [];
    final names = <String, String>{for (final c in categories) c.id: c.name};

    return AppDetailScaffold(
      eyebrow: 'Accounting',
      title: 'Expenses',
      actions: [
        PermissionGate(
          module: 'accounting',
          action: 'create',
          child: AppButton(
            label: 'New expense',
            icon: LucideIcons.plus,
            size: AppButtonSize.sm,
            onPressed: () => context.push('/accounting/expenses/create'),
          ),
        ),
      ],
      child: state.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.only(top: 30),
          child: AppErrorState(
            title: 'Couldn\'t load expenses',
            body: 'Your data is safe. Check the connection and try again.',
            onRetry: () => ref.read(expensesProvider.notifier).refresh(),
          ),
        ),
        data: (expenses) => expenses.isEmpty
            ? const Padding(
                padding: EdgeInsets.only(top: 20),
                child: AppEmptyState(
                  icon: LucideIcons.wallet,
                  title: 'No expenses yet',
                  body: 'Record an expense and it\'ll appear here.',
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final e in expenses) ...[
                    _ExpenseCard(
                      expense: e,
                      category: names[e.categoryId],
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.expense, required this.category});
  final Expense expense;
  final String? category;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          AcctIconTile(
            icon: LucideIcons.wallet,
            background: lum.surface2,
            foreground: lum.g600,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category ?? 'Uncategorised',
                  style: AppTypography.headline
                      .copyWith(fontSize: 14.5, color: lum.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${acctFormatDate(expense.expenseDate)}'
                  '${expense.paymentMethod == null ? '' : ' · ${acctRefLabel(expense.paymentMethod)}'}',
                  style: AppTypography.subhead
                      .copyWith(fontSize: 12.5, color: lum.g500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppMoneyText(expense.amount, size: 14),
              if (expense.taxAmount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: AcctMono(
                    '+${formatAmount(expense.taxAmount, decimals: 0)} tax',
                    align: TextAlign.right,
                    size: 11.5,
                    color: lum.g500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
