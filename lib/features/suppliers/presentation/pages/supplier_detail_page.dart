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
import '../../domain/entities/supplier.dart';
import '../../domain/entities/supplier_ledger.dart';
import '../../domain/usecases/load_supplier.dart';
import '../controllers/suppliers_controller.dart';

final _supplierProvider =
    FutureProvider.autoDispose.family<Supplier, String>((ref, id) async {
  final (supplier, failure) =
      await ref.read(loadSupplierUseCaseProvider).call(id);
  if (failure != null) throw failure;
  return supplier!;
});

class SupplierDetailPage extends ConsumerWidget {
  const SupplierDetailPage({super.key, required this.supplierId});
  final String supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierAsync = ref.watch(_supplierProvider(supplierId));

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
        title: Text('Supplier', style: AppTypography.headline),
        actions: [
          PermissionGate(
            module: 'purchase',
            action: 'update',
            child: IconButton(
              icon: const Icon(Icons.edit, color: AppColors.accent, size: 20),
              onPressed: () =>
                  context.push('/suppliers/$supplierId/edit'),
            ),
          ),
          PermissionGate(
            module: 'purchase',
            action: 'delete',
            child: IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.destructive, size: 20),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ),
        ],
      ),
      body: supplierAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding),
            child: AppInlineBanner(
                message: 'Could not load supplier.',
                type: BannerType.error),
          ),
        ),
        data: (supplier) => _Body(supplier: supplier),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: const Text(
            'Soft-delete this supplier? It will be hidden from lists.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final failure =
                  await ref.read(suppliersProvider.notifier).remove(supplierId);
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
  const _Body({required this.supplier});
  final Supplier supplier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(supplierLedgerProvider(supplier.id));

    return ListView(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
      children: [
        _HeaderCard(supplier: supplier),
        const SizedBox(height: AppSpacing.md),
        ledgerAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => AppInlineBanner(
              message: 'Could not load supplier ledger.',
              type: BannerType.error),
          data: (ledger) => _LedgerSection(ledger: ledger),
        ),
        const SizedBox(height: AppSpacing.xl),
        PermissionGate(
          module: 'purchase',
          action: 'create',
          child: AppButton(
            label: 'Record Payment',
            icon: Icons.payments,
            onPressed: () => context.push(
              '/purchasing/payments/create',
              extra: {'supplierId': supplier.id},
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.supplier});
  final Supplier supplier;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(supplier.name, style: AppTypography.largeTitle),
                ),
                _StatusBadge(status: supplier.status),
              ],
            ),
            if (supplier.contactPerson != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _line(Icons.person, supplier.contactPerson!),
            ],
            if (supplier.phone != null) _line(Icons.phone, supplier.phone!),
            if (supplier.email != null) _line(Icons.email, supplier.email!),
            const SizedBox(height: AppSpacing.sm),
            _line(Icons.schedule, 'Terms: ${supplier.paymentTerms} days'),
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

class _LedgerSection extends StatelessWidget {
  const _LedgerSection({required this.ledger});
  final SupplierLedger ledger;

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
  final SupplierLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final isInvoice = entry.kind == 'INVOICE';
    final amount = isInvoice ? entry.debit : entry.credit;
    final color = isInvoice ? AppColors.destructive : AppColors.success;
    final icon = switch (entry.kind) {
      'INVOICE' => Icons.receipt_long,
      'RETURN' => Icons.assignment_return,
      _ => Icons.payments,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.reference ?? entry.kind,
                    style: AppTypography.footnote),
                Text(
                  'Running: ${formatPkr(entry.runningBalance)}',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textHint),
                ),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final SupplierStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      SupplierStatus.active => (AppColors.success, 'Active'),
      SupplierStatus.inactive => (AppColors.textMuted, 'Inactive'),
      SupplierStatus.blacklisted => (AppColors.destructive, 'Blacklisted'),
    };
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(label,
          style: AppTypography.caption
              .copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
