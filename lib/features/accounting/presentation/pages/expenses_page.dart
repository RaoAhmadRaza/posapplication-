import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/expense.dart';
import '../controllers/expenses_controller.dart';

class ExpensesPage extends ConsumerWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(expensesProvider);
    final categories =
        ref.watch(expenseCategoriesProvider).value ?? const [];
    final names = <String, String>{
      for (final c in categories) c.id: c.name,
    };

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
        title: Text('Expenses', style: AppTypography.headline),
      ),
      floatingActionButton: PermissionGate(
        module: 'accounting',
        action: 'create',
        child: FloatingActionButton(
          backgroundColor: AppColors.accent,
          onPressed: () => context.push('/accounting/expenses/create'),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(
            onRetry: () => ref.read(expensesProvider.notifier).refresh(),
          ),
          data: (expenses) => expenses.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPadding,
                      vertical: AppSpacing.md),
                  itemCount: expenses.length,
                  itemBuilder: (_, i) => Padding(
                    padding: EdgeInsets.only(
                        bottom:
                            i < expenses.length - 1 ? AppSpacing.md : 0),
                    child: _ExpenseCard(
                      expense: expenses[i],
                      category: names[expenses[i].categoryId],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.expense, required this.category});
  final Expense expense;
  final String? category;

  String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(expense.expenseNumber ?? 'Expense',
                    style: AppTypography.headline),
              ),
              Text(formatPkr(expense.amount + expense.taxAmount),
                  style: AppTypography.headline),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category ?? 'Uncategorized',
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.textMuted)),
              Text(_date(expense.expenseDate),
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMuted)),
            ],
          ),
          if (expense.description != null &&
              expense.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(expense.description!,
                style: AppTypography.footnote
                    .copyWith(color: AppColors.textHint)),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.money_off, size: 48, color: AppColors.textHint),
          const SizedBox(height: AppSpacing.md),
          Text('No expenses yet',
              style:
                  AppTypography.subhead.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppInlineBanner(
                message: 'Could not load expenses.',
                type: BannerType.error),
            const SizedBox(height: AppSpacing.md),
            AppButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
