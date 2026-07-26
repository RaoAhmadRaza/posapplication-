import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../suppliers/domain/entities/supplier.dart';
import '../../../suppliers/presentation/controllers/suppliers_controller.dart';
import '../../domain/entities/purchase_invoice.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/entities/supplier_payment.dart';
import '../controllers/purchase_invoices_controller.dart';
import '../controllers/purchase_orders_controller.dart';
import '../widgets/purchasing_ui.dart';

class PurchaseInvoiceDetailPage extends ConsumerWidget {
  const PurchaseInvoiceDetailPage({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices =
        ref.watch(purchaseInvoicesProvider).value ?? const <PurchaseInvoice>[];
    final invoice = invoices.where((i) => i.id == invoiceId).firstOrNull;

    if (invoice == null) {
      return const AppDetailScaffold(
        eyebrow: 'Purchase invoice',
        title: 'Invoice',
        child: AppEmptyState(
          icon: LucideIcons.receiptText,
          title: 'Invoice not loaded',
          body: 'Open it from the invoices list.',
        ),
      );
    }
    return _Body(invoice: invoice);
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.invoice});
  final PurchaseInvoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final suppliers = ref.watch(suppliersProvider).value ?? const <Supplier>[];
    final supplierName = suppliers
            .where((s) => s.id == invoice.supplierId)
            .map((s) => s.name)
            .firstOrNull ??
        'Supplier ${invoice.supplierId.substring(0, 6)}';
    final billNo = invoice.supplierInvoiceNumber?.trim();
    final (tone, label) = invoiceStatusPill(invoice.status);
    final paymentsAsync = ref.watch(invoicePaymentsProvider(invoice.id));

    final orders =
        ref.watch(purchaseOrdersProvider).value ?? const <PurchaseOrder>[];
    final poNumber = orders
        .where((o) => o.id == invoice.poId)
        .map((o) => o.poNumber)
        .firstOrNull;

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionCard(
          eyebrow: 'Summary',
          trailing: AppPill(label: label, tone: tone),
          child: _SummaryGrid(invoice: invoice),
        ),
        const SizedBox(height: 14),
        AppSectionCard(
          eyebrow: 'Payments',
          child: paymentsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Unable to load payment history.',
                style: AppTypography.footnote.copyWith(color: lum.dangerText)),
            data: (payments) => payments.isEmpty
                ? Text('No payments recorded yet.',
                    style: AppTypography.footnote.copyWith(color: lum.g500))
                : Column(
                    children: [
                      for (final p in payments) _PaymentRow(payment: p),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 14),
        AppSectionCard(
          eyebrow: 'Linked PO',
          child: InkWell(
            onTap: () => context.push('/purchasing/orders/${invoice.poId}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(LucideIcons.clipboardList, size: 18, color: lum.g500),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      poNumber ?? 'PO ${invoice.poId.substring(0, 8)}',
                      style: AppTypography.subhead.copyWith(
                        fontFamily: AppTypography.mono,
                        color: lum.textPrimary,
                      ),
                    ),
                  ),
                  Icon(LucideIcons.chevronRight, size: 18, color: lum.g400),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    final actions = <Widget>[
      if (invoice.balance > 0)
        PermissionGate(
          module: 'purchase',
          action: 'create',
          child: AppButton(
            label: 'Record payment',
            icon: LucideIcons.wallet,
            fullWidth: true,
            onPressed: () => context.push(
              '/purchasing/payments/create',
              extra: {
                'supplierId': invoice.supplierId,
                'invoiceId': invoice.id,
                'balance': invoice.balance,
              },
            ),
          ),
        ),
      PermissionGate(
        module: 'purchase',
        action: 'update',
        child: AppButton(
          label: 'Return against bill',
          icon: LucideIcons.undo2,
          variant: AppButtonVariant.tinted,
          fullWidth: true,
          onPressed: () => context.push(
            '/purchasing/returns/create',
            extra: {'poId': invoice.poId, 'invoiceId': invoice.id},
          ),
        ),
      ),
    ];
    final right = AppSectionCard(
      eyebrow: 'Actions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            actions[i],
          ],
        ],
      ),
    );

    return AppDetailScaffold(
      eyebrow: 'Purchase invoice',
      title: billNo == null || billNo.isEmpty ? 'Invoice' : billNo,
      description: supplierName,
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= 760) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: left),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: right),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 14), right],
          );
        },
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.invoice});
  final PurchaseInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final tiles = <Widget>[
      _StatTile(label: 'Amount', value: invoice.amount),
      _StatTile(label: 'Tax', value: invoice.taxAmount),
      _StatTile(label: 'Total', value: invoice.totalAmount),
      _StatTile(label: 'Paid', value: invoice.paidAmount),
      _StatTile(
        label: 'Balance',
        value: invoice.balance,
        color: invoice.balance > 0 ? lum.warningText : lum.successText,
      ),
      _DueTile(dueDate: invoice.dueDate),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 420 ? 3 : 2;
        const gap = 10.0;
        final w = (c.maxWidth - (cols - 1) * gap) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.color});
  final String label;
  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return ClayContainer(
      variant: ClayVariant.inset,
      color: lum.surface2,
      borderRadius: AppRadius.md,
      isDark: lum.isDark,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: lum.g400,
              )),
          const SizedBox(height: 5),
          AppMoneyText(value, size: 17, color: color),
        ],
      ),
    );
  }
}

class _DueTile extends StatelessWidget {
  const _DueTile({required this.dueDate});
  final DateTime? dueDate;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return ClayContainer(
      variant: ClayVariant.inset,
      color: lum.surface2,
      borderRadius: AppRadius.md,
      isDark: lum.isDark,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DUE DATE',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: lum.g400,
              )),
          const SizedBox(height: 5),
          Text(
            dueDate == null ? '—' : ymd(dueDate!),
            style: AppTypography.monoValue
                .copyWith(fontSize: 17, color: lum.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});
  final SupplierPayment payment;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final ref = payment.reference?.trim().isNotEmpty == true
        ? payment.reference!.trim()
        : payment.voucherNumber?.trim();
    final meta =
        ref == null || ref.isEmpty ? ymd(payment.paidAt) : '${ymd(payment.paidAt)} · $ref';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          ClayContainer(
            variant: ClayVariant.soft,
            color: lum.successSoft,
            borderRadius: AppRadius.sm,
            isDark: lum.isDark,
            width: 34,
            height: 34,
            child: Center(
              child: Icon(LucideIcons.arrowDownLeft,
                  size: 16, color: lum.successText),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.method,
                    style: AppTypography.subhead
                        .copyWith(color: lum.textPrimary)),
                const SizedBox(height: 2),
                Text(meta,
                    style: AppTypography.caption.copyWith(color: lum.g500)),
              ],
            ),
          ),
          AppMoneyText(payment.amount, size: 15, color: lum.successText),
        ],
      ),
    );
  }
}
