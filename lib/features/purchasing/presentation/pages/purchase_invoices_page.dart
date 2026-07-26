import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_filter_chips.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../suppliers/domain/entities/supplier.dart';
import '../../../suppliers/presentation/controllers/suppliers_controller.dart';
import '../../domain/entities/purchase_invoice.dart';
import '../controllers/purchase_invoices_controller.dart';
import '../widgets/purchasing_ui.dart';

class PurchaseInvoicesPage extends ConsumerWidget {
  const PurchaseInvoicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(purchaseInvoicesProvider);
    final active = ref.watch(purchaseInvoicesProvider.notifier).statusFilter;
    final suppliers = ref.watch(suppliersProvider).value ?? const <Supplier>[];

    const statuses = PurchaseInvoiceStatus.values;
    final labels = ['All', for (final s in statuses) invoiceStatusPill(s).$2];
    final selected = active == null ? 0 : statuses.indexOf(active) + 1;
    void onSelected(int i) => ref
        .read(purchaseInvoicesProvider.notifier)
        .setStatus(i == 0 ? null : statuses[i - 1]);

    return AppDetailScaffold(
      eyebrow: 'Purchasing',
      title: 'Purchase invoices',
      description: "Bills are raised from a PO — there's no manual create.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppFilterChips(
            labels: labels,
            selected: selected,
            onSelected: onSelected,
          ),
          const SizedBox(height: 18),
          switch (state) {
            AsyncError() => AppErrorState(
                title: 'Unable to load invoices',
                body: 'Unable to load suggestions. Check your connection and try again.',
                onRetry: () =>
                    ref.read(purchaseInvoicesProvider.notifier).refresh(),
              ),
            AsyncData(:final value) when value.isEmpty => const AppEmptyState(
                icon: LucideIcons.receiptText,
                title: 'No invoices yet',
                body: 'Invoices appear here once created from a received order.',
              ),
            AsyncData(:final value) => Column(
                children: [
                  for (final inv in value) ...[
                    _InvoiceCard(
                      invoice: inv,
                      supplierName: _supplierName(suppliers, inv.supplierId),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            _ => const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              ),
          },
        ],
      ),
    );
  }

  static String _supplierName(List<Supplier> suppliers, String id) =>
      suppliers.where((s) => s.id == id).map((s) => s.name).firstOrNull ??
      'Supplier ${id.substring(0, 6)}';
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice, required this.supplierName});
  final PurchaseInvoice invoice;
  final String supplierName;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final (tone, label) = invoiceStatusPill(invoice.status);
    final settled = invoice.balance <= 0;

    // The schema has no internal invoice number — the vendor's bill number is
    // the human identifier we hold.
    final billNo = invoice.supplierInvoiceNumber?.trim();

    return AppCard(
      onTap: () => context.push('/purchasing/invoices/${invoice.id}'),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        billNo == null || billNo.isEmpty ? 'Bill' : billNo,
                        style: AppTypography.monoValue.copyWith(
                          fontSize: 15,
                          color: lum.textPrimary,
                        ),
                      ),
                    ),
                    AppPill(label: label, tone: tone),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  supplierName,
                  style: AppTypography.subhead.copyWith(color: lum.textPrimary),
                ),
                if (invoice.dueDate != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Due ${ymd(invoice.dueDate!)}',
                    style: AppTypography.footnote.copyWith(color: lum.g500),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppMoneyText(invoice.totalAmount, size: 18),
              const SizedBox(height: 3),
              settled
                  ? Text(
                      'Settled',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: lum.successText,
                      ),
                    )
                  : Text(
                      'Balance ${formatAmount(invoice.balance)}',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: lum.warningText,
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
