import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_ledger.dart';
import '../../domain/usecases/load_customer.dart';
import '../controllers/customers_controller.dart';

final _customerProvider =
    FutureProvider.autoDispose.family<Customer, String>((ref, id) async {
  final (customer, failure) =
      await ref.read(loadCustomerUseCaseProvider).call(id);
  if (failure != null) throw failure;
  return customer!;
});

class CustomerDetailPage extends ConsumerWidget {
  const CustomerDetailPage({super.key, required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(_customerProvider(customerId));

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
        title: Text('Customer', style: AppTypography.headline),
        actions: [
          PermissionGate(
            module: 'sales',
            action: 'create',
            child: IconButton(
              icon: const Icon(Icons.payments_outlined,
                  color: AppColors.accent, size: 20),
              onPressed: () => customerAsync.whenData((c) {
                context.push('/customers/$customerId/collect',
                    extra: {'customerName': c.name});
              }),
            ),
          ),
          PermissionGate(
            module: 'customers',
            action: 'update',
            child: IconButton(
              icon: const Icon(Icons.edit, color: AppColors.accent, size: 20),
              onPressed: () => context.push('/customers/$customerId/edit'),
            ),
          ),
          PermissionGate(
            module: 'customers',
            action: 'delete',
            child: IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.destructive, size: 20),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ),
        ],
      ),
      body: customerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding),
            child: AppInlineBanner(
                message: 'Could not load customer.',
                type: BannerType.error),
          ),
        ),
        data: (customer) => _Body(customer: customer),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer'),
        content: const Text(
            'Soft-delete this customer? It will be hidden from lists.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final failure =
                  await ref.read(customersProvider.notifier).remove(customerId);
              if (!context.mounted) return;
              if (failure != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(failure.message)));
                return;
              }
              Navigator.of(context).pop();
            },
            child: Text('Delete',
                style: TextStyle(color: AppColors.destructive)),
          ),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.customer});
  final Customer customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(customerLedgerProvider(customer.id));

    return ListView(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
      children: [
        _HeaderCard(customer: customer),
        const SizedBox(height: AppSpacing.md),
        ledgerAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => AppInlineBanner(
              message: 'Could not load customer ledger.',
              type: BannerType.error),
          data: (ledger) => Column(
            children: [
              _CreditSummaryCard(customer: customer, ledger: ledger),
              const SizedBox(height: AppSpacing.md),
              _LedgerSection(ledger: ledger),
              if (ledger.outstanding > 0) ...[
                const SizedBox(height: AppSpacing.lg),
                PermissionGate(
                  module: 'sales',
                  action: 'create',
                  child: AppButton(
                    label: 'Collect Payment',
                    icon: Icons.payments_outlined,
                    fullWidth: true,
                    onPressed: () => context.push(
                      '/customers/${customer.id}/collect',
                      extra: {'customerName': customer.name},
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.customer});
  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (customer.status) {
      CustomerStatus.active => (AppColors.success, 'Active'),
      CustomerStatus.inactive => (AppColors.textMuted, 'Inactive'),
      CustomerStatus.blacklisted => (AppColors.destructive, 'Blacklisted'),
    };
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(customer.name, style: AppTypography.largeTitle),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Text(label,
                      style: AppTypography.caption.copyWith(
                          color: color, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            if (customer.phone != null) _line(Icons.phone, customer.phone!),
            if (customer.email != null) _line(Icons.email, customer.email!),
            const SizedBox(height: AppSpacing.sm),
            _line(Icons.schedule, 'Terms: ${customer.creditTerms} days'),
          ],
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(icon, size: 15, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
                child: Text(text,
                    style: AppTypography.footnote
                        .copyWith(color: AppColors.textMuted))),
          ],
        ),
      );
}

class _CreditSummaryCard extends StatelessWidget {
  const _CreditSummaryCard({required this.customer, required this.ledger});
  final Customer customer;
  final CustomerLedger ledger;

  @override
  Widget build(BuildContext context) {
    final limit = customer.creditLimit;
    final outstanding = ledger.outstanding;
    final remaining = limit - outstanding;
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CREDIT',
                style: AppTypography.footnote.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            _row('Credit Limit', formatPkr(limit)),
            _row('Outstanding', formatPkr(outstanding),
                color: outstanding > 0
                    ? AppColors.destructive
                    : AppColors.textPrimary),
            const Divider(color: AppColors.separator, height: AppSpacing.xl),
            _row(
              limit > 0 ? 'Remaining Credit' : 'Remaining Credit (no limit set)',
              limit > 0 ? formatPkr(remaining) : '—',
              emphasize: true,
              color: limit > 0 && remaining <= 0
                  ? AppColors.destructive
                  : AppColors.success,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value,
      {bool emphasize = false, Color? color}) {
    final style = emphasize
        ? AppTypography.headline
        : AppTypography.footnote.copyWith(color: AppColors.textMuted);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _LedgerSection extends StatelessWidget {
  const _LedgerSection({required this.ledger});
  final CustomerLedger ledger;

  @override
  Widget build(BuildContext context) {
    final owed = ledger.currentBalance;
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Balance', style: AppTypography.footnote),
                Text(formatPkr(owed),
                    style: AppTypography.headline.copyWith(
                        color: owed > 0
                            ? AppColors.destructive
                            : AppColors.textPrimary)),
              ],
            ),
            const Divider(color: AppColors.separator, height: AppSpacing.xl),
            Text('Ledger', style: AppTypography.footnote),
            const SizedBox(height: AppSpacing.sm),
            if (ledger.entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text('No transactions yet.',
                    style: AppTypography.footnote
                        .copyWith(color: AppColors.textHint)),
              )
            else
              for (final e in ledger.entries) _EntryRow(entry: e),
          ],
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});
  final CustomerLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final isInvoice = entry.kind == 'INVOICE';
    final amount = isInvoice ? entry.debit : entry.credit;
    final color = isInvoice ? AppColors.destructive : AppColors.success;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(isInvoice ? Icons.receipt_long : Icons.payments,
              size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.reference ?? entry.kind,
                    style: AppTypography.footnote),
                Text('Running: ${formatPkr(entry.runningBalance)}',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textHint)),
              ],
            ),
          ),
          Text('${isInvoice ? '+' : '-'}${formatPkr(amount)}',
              style: AppTypography.footnote
                  .copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
