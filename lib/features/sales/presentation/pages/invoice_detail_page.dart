import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/widgets/no_access_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/customer.dart';
import '../../data/services/receipt_pdf_service.dart';
import '../controllers/customers_controller.dart';
import '../controllers/invoices_controller.dart';

class InvoiceDetailPage extends ConsumerWidget {
  const InvoiceDetailPage({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PermissionGate(
      module: 'sales',
      action: 'read',
      fallback: const NoAccessScaffold(),
      child: _buildGated(context, ref),
    );
  }

  Widget _buildGated(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(invoicesProvider).value ?? [];
    // Route param may arrive as either the UUID id (sales history, repair) or
    // the human invoice_number (dashboard recent-sale, sales/receivables/product
    // drilldowns). Both resolve against the same RLS-scoped list, so a match can
    // never cross tenants; invoice_number is unique within scope and never
    // collides with a UUID.
    final invoice = invoices
        .where((i) => i.id == invoiceId || i.invoiceNumber == invoiceId)
        .firstOrNull;
    final customers = ref.watch(customersProvider).value ?? <Customer>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(invoice?.invoiceNumber ?? 'Invoice', style: AppTypography.headline),
      ),
      body: invoice == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<Map<String, dynamic>?>(
              future: ref.read(invoicesProvider.notifier).loadDetail(invoice.id),
              builder: (context, snapshot) {
                final detail = snapshot.data;
                if (detail == null) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return Center(
                    child: Text('Could not load invoice.', style: AppTypography.subhead.copyWith(color: AppColors.textMuted)),
                  );
                }
              return _buildContent(context, invoice, detail, customers, ref);
                },
            ),
    );
  }

  Widget _buildContent(BuildContext context, dynamic invoice, Map<String, dynamic> detail, List<Customer> customers, WidgetRef ref) {
    final customerName = _resolveCustomerName(invoice.customerId?.toString(), customers);
    final items = (detail['invoice_items'] as List<dynamic>?) ?? [];
    final payments = (detail['payments'] as List<dynamic>?) ?? [];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.xl),
            _HeaderCard(invoice: invoice, customerName: customerName),
            const SizedBox(height: AppSpacing.xl),
            Text('Items', style: AppTypography.headline),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: items.map((item) => _ItemRow(item as Map<String, dynamic>)).toList(),
              ),
            ),
            if (payments.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              Text('Payments', style: AppTypography.headline),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: payments.map((p) => _PaymentRow(p as Map<String, dynamic>)).toList(),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            _TotalsCard(invoice: invoice),
            const SizedBox(height: AppSpacing.xxl),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Reprint',
                    onPressed: () async {
                      final service = ReceiptPdfService();
                      final bytes = await service.buildReceipt(detail);
                      await Printing.layoutPdf(onLayout: (_) => bytes, name: 'receipt_${invoice.invoiceNumber}');
                    },
                    icon: Icons.print,
                    variant: AppButtonVariant.tinted,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: 'Share',
                    onPressed: () async {
                      final service = ReceiptPdfService();
                      final bytes = await service.buildReceipt(detail);
                      await Printing.sharePdf(bytes: bytes, filename: 'receipt_${invoice.invoiceNumber}.pdf');
                    },
                    icon: Icons.share,
                    variant: AppButtonVariant.plain,
                  ),
                ),
              ],
            ),
            if (!_isVoided(invoice)) ...[
              const SizedBox(height: AppSpacing.md),
              PermissionGate(
                module: 'sales',
                action: 'delete',
                child: AppButton(
                  label: 'Void Invoice',
                  onPressed: () => _doVoid(context, ref, invoice, detail),
                  fullWidth: true,
                  variant: AppButtonVariant.destructive,
                  icon: Icons.cancel_outlined,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  String _resolveCustomerName(String? customerId, List<Customer> customers) {
    if (customerId == null) return 'Walk-in';
    return customers.where((c) => c.id == customerId).firstOrNull?.name ?? 'Walk-in';
  }

  static bool _isVoided(dynamic invoice) {
    final status = invoice.status.toString().split('.').last.toUpperCase();
    return status == 'VOID' || status == 'VOIDED' || status == 'RETURNED';
  }

  static Future<void> _doVoid(BuildContext context, WidgetRef ref, dynamic invoice, Map<String, dynamic> detail) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Void Invoice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Void invoice ${invoice.invoiceNumber}? This will restock all items.', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(hintText: 'Reason for voiding'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Void'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(const SnackBar(content: Text('Voiding invoice...'), duration: Duration(seconds: 1)));

    final failure = await ref.read(invoicesProvider.notifier).voidInvoice(
      invoiceId: invoice.id.toString(),
      reason: reasonCtrl.text.trim().isEmpty ? 'No reason given' : reasonCtrl.text.trim(),
    );

    if (!context.mounted) return;
    if (failure != null) {
      scaffold.showSnackBar(SnackBar(content: Text(failure.message), backgroundColor: Colors.red));
    } else {
      scaffold.showSnackBar(const SnackBar(content: Text('Invoice voided.')));
      Navigator.of(context).pop();
    }
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.invoice, required this.customerName});
  final dynamic invoice;
  final String customerName;

  @override
  Widget build(BuildContext context) {
    final status = invoice.status.toString().split('.').last.toUpperCase();
    final (color, label) = switch (status) {
      'PAID' => (AppColors.success, 'PAID'),
      'PARTIALLYPAID' => (AppColors.warning, 'PARTIALLY PAID'),
      'CONFIRMED' => (AppColors.accent, 'CREDIT'),
      'RETURNED' => (AppColors.destructive, 'RETURNED'),
      'VOID' => (AppColors.textMuted, 'VOID'),
      _ => (AppColors.textHint, status),
    };

    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(invoice.invoiceNumber, style: AppTypography.title2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Text(label, style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _DetailRow(label: 'Date', value: _formatDate(invoice.createdAt)),
          _DetailRow(label: 'Customer', value: customerName),
          if (invoice.notes != null && (invoice.notes as String).isNotEmpty)
            _DetailRow(label: 'Notes', value: invoice.notes.toString()),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
          Text(value, style: AppTypography.subhead),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow(this.item);
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final qty = double.tryParse(item['qty']?.toString() ?? '0') ?? 0;
    final price = double.tryParse(item['unit_price']?.toString() ?? '0') ?? 0;
    final total = double.tryParse(item['line_total']?.toString() ?? '0') ?? 0;
    final desc = item['description']?.toString() ?? '';
    final dp = double.tryParse(item['discount_pct']?.toString() ?? '0') ?? 0;
    final tp = double.tryParse(item['tax_pct']?.toString() ?? '0') ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${qty.toStringAsFixed(0)} x ${formatPkr(price)}', style: AppTypography.subhead),
              const Spacer(),
              Text(formatPkr(total), style: AppTypography.headline.copyWith(color: AppColors.accent)),
            ],
          ),
          if (desc.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(desc, style: AppTypography.caption.copyWith(color: AppColors.textHint)),
            ),
          if (dp > 0 || tp > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${dp > 0 ? 'Disc ${dp.toStringAsFixed(0)}% ' : ''}${tp > 0 ? 'Tax ${tp.toStringAsFixed(0)}%' : ''}',
                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
            ),
          const Divider(color: AppColors.separator, height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow(this.payment);
  final Map<String, dynamic> payment;

  @override
  Widget build(BuildContext context) {
    final method = payment['method']?.toString() ?? '';
    final amount = double.tryParse(payment['amount']?.toString() ?? '0') ?? 0;
    final ref = payment['reference']?.toString();

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(method, style: AppTypography.subhead),
              const Spacer(),
              Text(formatPkr(amount), style: AppTypography.headline.copyWith(color: AppColors.accent)),
            ],
          ),
          if (ref != null && ref.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Ref: $ref', style: AppTypography.caption.copyWith(color: AppColors.textHint)),
            ),
          const Divider(color: AppColors.separator, height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.invoice});
  final dynamic invoice;

  @override
  Widget build(BuildContext context) {
    final grand = (invoice.grandTotal as num).toDouble();
    final paid = (invoice.paidAmount as num).toDouble();
    final change = (invoice.changeAmount as num).toDouble();
    final balance = (invoice.balance as num).toDouble();
    final discount = (invoice.discountTotal as num).toDouble();
    final tax = (invoice.taxTotal as num).toDouble();

    return AppCard(
      child: Column(
        children: [
          _TotalLine(label: 'Subtotal', value: grand, muted: true),
          if (discount > 0) _TotalLine(label: 'Discount', value: discount, muted: true),
          if (tax > 0) _TotalLine(label: 'Tax', value: tax, muted: true),
          _TotalLine(label: 'Grand Total', value: grand, bold: true),
          const Divider(color: AppColors.separator, height: AppSpacing.base),
          _TotalLine(label: 'Paid', value: paid),
          if (change > 0) _TotalLine(label: 'Change', value: change, color: AppColors.success),
          if (balance > 0) _TotalLine(label: 'Balance Due', value: balance, bold: true, color: AppColors.warning),
        ],
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({required this.label, required this.value, this.bold = false, this.muted = false, this.color});
  final String label;
  final double value;
  final bool bold;
  final bool muted;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: (bold ? AppTypography.headline : AppTypography.footnote).copyWith(
            color: muted ? AppColors.textMuted : AppColors.textPrimary,
          )),
          Text(
            formatPkr(value),
            style: (bold ? AppTypography.headline : AppTypography.footnote).copyWith(
              color: color ?? AppColors.textPrimary,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
