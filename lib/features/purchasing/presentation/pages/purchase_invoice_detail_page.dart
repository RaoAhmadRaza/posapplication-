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
import '../../domain/entities/purchase_invoice.dart';
import '../../domain/entities/supplier_payment.dart';
import '../controllers/purchase_invoices_controller.dart';

const _statusLabels = {
  PurchaseInvoiceStatus.draft: 'Draft',
  PurchaseInvoiceStatus.pending: 'Pending',
  PurchaseInvoiceStatus.approved: 'Approved',
  PurchaseInvoiceStatus.paid: 'Paid',
  PurchaseInvoiceStatus.void_: 'Void',
};

Color _statusColor(PurchaseInvoiceStatus s) => switch (s) {
      PurchaseInvoiceStatus.draft => AppColors.textMuted,
      PurchaseInvoiceStatus.pending => AppColors.accent,
      PurchaseInvoiceStatus.approved => AppColors.success,
      PurchaseInvoiceStatus.paid => AppColors.success,
      PurchaseInvoiceStatus.void_ => AppColors.destructive,
    };

class PurchaseInvoiceDetailPage extends ConsumerWidget {
  const PurchaseInvoiceDetailPage({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices =
        ref.watch(purchaseInvoicesProvider).value ?? const <PurchaseInvoice>[];
    final invoice = invoices.where((i) => i.id == invoiceId).firstOrNull;

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
        title: Text('Invoice', style: AppTypography.headline),
      ),
      body: invoice == null
          ? const _MissingInvoice()
          : _Body(invoice: invoice),
    );
  }
}

class _MissingInvoice extends StatelessWidget {
  const _MissingInvoice();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long, size: 48, color: AppColors.textHint),
            const SizedBox(height: AppSpacing.md),
            Text('Invoice not loaded',
                style: AppTypography.subhead
                    .copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.xs),
            Text('Open it from the invoices list.',
                textAlign: TextAlign.center,
                style: AppTypography.footnote
                    .copyWith(color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.invoice});
  final PurchaseInvoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(invoicePaymentsProvider(invoice.id));

    return ListView(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
      children: [
        _HeaderCard(invoice: invoice),
        const SizedBox(height: AppSpacing.md),
        Text('PAYMENTS',
            style: AppTypography.footnote.copyWith(
                color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.sm),
        paymentsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => AppInlineBanner(
              message: 'Could not load payment history.',
              type: BannerType.error),
          data: (payments) => _PaymentsSection(payments: payments),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (invoice.balance > 0)
          PermissionGate(
            module: 'purchase',
            action: 'create',
            child: AppButton(
              label: 'Record Payment',
              icon: Icons.payments,
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
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.invoice});
  final PurchaseInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final title = invoice.supplierInvoiceNumber ?? 'Supplier Invoice';
    final color = _statusColor(invoice.status);
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(title, style: AppTypography.largeTitle)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Text(_statusLabels[invoice.status]!,
                      style: AppTypography.caption.copyWith(
                          color: color, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const Divider(color: AppColors.separator, height: AppSpacing.xl),
            _amountRow('Amount', invoice.amount),
            _amountRow('Tax', invoice.taxAmount),
            _amountRow('Total', invoice.totalAmount, bold: true),
            _amountRow('Paid', invoice.paidAmount),
            _amountRow('Balance', invoice.balance,
                color: invoice.balance > 0
                    ? AppColors.destructive
                    : AppColors.textPrimary),
          ],
        ),
      ),
    );
  }

  Widget _amountRow(String label, double value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.footnote),
          Text(formatPkr(value),
              style: (bold ? AppTypography.headline : AppTypography.subhead)
                  .copyWith(color: color ?? AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _PaymentsSection extends StatelessWidget {
  const _PaymentsSection({required this.payments});
  final List<SupplierPayment> payments;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text('No payments recorded yet.',
              style:
                  AppTypography.footnote.copyWith(color: AppColors.textHint)),
        ),
      );
    }
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
        child: Column(
          children: [
            for (final p in payments) _PaymentRow(payment: p),
          ],
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});
  final SupplierPayment payment;

  @override
  Widget build(BuildContext context) {
    final d = payment.paidAt;
    final date =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.payments, size: 18, color: AppColors.success),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.voucherNumber ?? payment.method,
                    style: AppTypography.footnote),
                Text('${payment.method} · $date',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textHint)),
              ],
            ),
          ),
          Text(formatPkr(payment.amount),
              style: AppTypography.footnote.copyWith(
                  color: AppColors.success, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
