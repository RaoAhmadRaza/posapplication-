import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:printing/printing.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/widgets/no_access_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/customer.dart';
import '../../data/services/receipt_pdf_service.dart';
import '../controllers/customers_controller.dart';
import '../controllers/invoices_controller.dart';
import '../widgets/sales_empty_state.dart';
import '../widgets/sales_scaffold.dart';

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

    return SalesScaffold(
      title: invoice?.invoiceNumber ?? 'Invoice',
      maxContentWidth: 820,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      leading: _BackButton(onTap: () => Navigator.of(context).maybePop()),
      child: invoice == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<Map<String, dynamic>?>(
              future: ref.read(invoicesProvider.notifier).loadDetail(invoice.id),
              builder: (context, snapshot) {
                final detail = snapshot.data;
                if (detail == null) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return const SalesEmptyState(
                    icon: LucideIcons.receiptText,
                    message: "We couldn't load this invoice. Try again once "
                        'the connection is back.',
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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderCard(
            invoice: invoice,
            customerName: customerName,
            onVoid: _isVoided(invoice)
                ? null
                : () => _doVoid(context, ref, invoice),
          ),
          const SizedBox(height: 14),
          AppSectionCard(
            eyebrow: 'Items',
            padded: false,
            child: Column(
              children: [
                for (final item in items)
                  _ItemRow(item as Map<String, dynamic>),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Wrap rather than collapse: a section that vanishes silently widens
          // its neighbour and reads as a layout bug.
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _WrapCard(
                child: AppSectionCard(
                  eyebrow: 'Payments',
                  padded: false,
                  child: payments.isEmpty
                      ? const SalesEmptyState(
                          icon: LucideIcons.creditCard,
                          message: 'Nothing collected against this invoice yet.',
                          minHeight: 90,
                        )
                      : Column(
                          children: [
                            for (final p in payments)
                              _PaymentRow(p as Map<String, dynamic>),
                          ],
                        ),
                ),
              ),
              _WrapCard(child: _TotalsCard(invoice: invoice)),
            ],
          ),
          const SizedBox(height: 18),
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
                  icon: LucideIcons.printer,
                  variant: AppButtonVariant.tinted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Share',
                  onPressed: () async {
                    final service = ReceiptPdfService();
                    final bytes = await service.buildReceipt(detail);
                    await Printing.sharePdf(bytes: bytes, filename: 'receipt_${invoice.invoiceNumber}.pdf');
                  },
                  icon: LucideIcons.share2,
                  variant: AppButtonVariant.plain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
        ],
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

  static Future<void> _doVoid(
    BuildContext context,
    WidgetRef ref,
    dynamic invoice,
  ) async {
    // The design's confirm carries no reason box, but void_invoice requires a
    // reason, so the field stays — collapsed into the same dialog.
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final lum = dialogContext.lum;
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ClayContainer(
            variant: ClayVariant.raised,
            color: lum.surface,
            borderRadius: AppRadius.xl,
            isDark: lum.isDark,
            padding: const EdgeInsets.all(26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: lum.dangerSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.ban, size: 24, color: lum.dangerText),
                ),
                const SizedBox(height: 18),
                Text('Void this invoice?', style: AppTypography.title3),
                const SizedBox(height: 8),
                Text(
                  'This reverses the sale and returns items to stock. The '
                  'invoice stays on record marked as void. This can\'t be undone.',
                  style: AppTypography.footnote.copyWith(
                    height: 1.5,
                    color: lum.g600,
                  ),
                ),
                const SizedBox(height: 18),
                ClayContainer(
                  variant: ClayVariant.inset,
                  color: lum.surface2,
                  borderRadius: AppRadius.md,
                  isDark: lum.isDark,
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    child: TextField(
                      controller: reasonCtrl,
                      autofocus: true,
                      style: AppTypography.fieldText
                          .copyWith(color: lum.textPrimary),
                      cursorColor: lum.accent,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: 'Reason for voiding',
                        hintStyle: AppTypography.fieldHint
                            .copyWith(color: lum.textTertiary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                AppButton(
                  label: 'Void invoice',
                  fullWidth: true,
                  variant: AppButtonVariant.destructive,
                  onPressed: () => Navigator.pop(dialogContext, true),
                ),
                const SizedBox(height: 8),
                AppButton(
                  label: 'Keep it',
                  fullWidth: true,
                  variant: AppButtonVariant.plain,
                  onPressed: () => Navigator.pop(dialogContext, false),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    final failure = await ref.read(invoicesProvider.notifier).voidInvoice(
      invoiceId: invoice.id.toString(),
      reason: reasonCtrl.text.trim().isEmpty ? 'No reason given' : reasonCtrl.text.trim(),
    );

    if (!context.mounted) return;
    if (failure != null) {
      showAppToast(context, failure.message, type: BannerType.error);
    } else {
      showAppToast(context, 'Invoice voided.', type: BannerType.success);
      Navigator.of(context).maybePop();
    }
  }
}

/// Header row: number, status, customer, date and the destructive Void action.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.invoice,
    required this.customerName,
    required this.onVoid,
  });

  final dynamic invoice;
  final String customerName;
  final VoidCallback? onVoid;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final status = invoice.status.toString().split('.').last.toUpperCase();
    final (tone, label) = switch (status) {
      'PAID' => (AppPillTone.success, 'Paid'),
      'PARTIALLYPAID' => (AppPillTone.warning, 'Partially paid'),
      'CONFIRMED' => (AppPillTone.lumen, 'Credit'),
      'RETURNED' => (AppPillTone.danger, 'Returned'),
      'VOID' || 'VOIDED' => (AppPillTone.neutral, 'Void'),
      _ => (AppPillTone.neutral, status),
    };

    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        invoice.invoiceNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.monoValue.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: lum.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AppPill(label: label, tone: tone),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  customerName,
                  style: AppTypography.body.copyWith(color: lum.g600),
                ),
                Text(
                  _formatDate(invoice.createdAt),
                  style: AppTypography.footnote.copyWith(color: lum.g500),
                ),
                if (invoice.notes != null &&
                    (invoice.notes as String).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    invoice.notes.toString(),
                    style: AppTypography.footnote.copyWith(color: lum.g500),
                  ),
                ],
              ],
            ),
          ),
          if (onVoid != null) ...[
            const SizedBox(width: 12),
            PermissionGate(
              module: 'sales',
              action: 'delete',
              child: AppButton(
                label: 'Void',
                onPressed: onVoid,
                variant: AppButtonVariant.destructive,
                icon: LucideIcons.ban,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

/// Half-width card on wide layouts, full width once it cannot fit.
class _WrapCard extends StatelessWidget {
  const _WrapCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final half = (available - 14) / 2;
        return SizedBox(
          width: half >= 260 ? half : available,
          child: child,
        );
      },
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow(this.item);
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final qty = double.tryParse(item['qty']?.toString() ?? '0') ?? 0;
    final price = double.tryParse(item['unit_price']?.toString() ?? '0') ?? 0;
    final total = double.tryParse(item['line_total']?.toString() ?? '0') ?? 0;
    final desc = item['description']?.toString() ?? '';
    final dp = double.tryParse(item['discount_pct']?.toString() ?? '0') ?? 0;
    final tp = double.tryParse(item['tax_pct']?.toString() ?? '0') ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  // invoice_items carries no product name or SKU, only the
                  // description captured at sale time.
                  desc.isEmpty ? 'Item' : desc,
                  style: AppTypography.label.copyWith(color: lum.textPrimary),
                ),
                Text(
                  '${formatPkr(price)} × ${qty.toStringAsFixed(0)}'
                  '${dp > 0 ? ' · disc ${dp.toStringAsFixed(0)}%' : ''}'
                  '${tp > 0 ? ' · tax ${tp.toStringAsFixed(0)}%' : ''}',
                  style: AppTypography.monoValue.copyWith(
                    fontSize: 11.5,
                    color: lum.g500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AppMoneyText(total, size: 14),
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
    final lum = context.lum;
    final method = payment['method']?.toString() ?? '';
    final amount = double.tryParse(payment['amount']?.toString() ?? '0') ?? 0;
    final reference = payment['reference']?.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _label(method),
                  style: AppTypography.body.copyWith(color: lum.g600),
                ),
                if (reference != null && reference.isNotEmpty)
                  Text(
                    'Ref $reference',
                    style: AppTypography.monoValue.copyWith(
                      fontSize: 11.5,
                      color: lum.g500,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AppMoneyText(amount, size: 14),
        ],
      ),
    );
  }

  static String _label(String raw) {
    if (raw.isEmpty) return 'Payment';
    return raw
        .toLowerCase()
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.invoice});
  final dynamic invoice;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final grand = (invoice.grandTotal as num).toDouble();
    final subtotal = (invoice.subtotal as num).toDouble();
    final paid = (invoice.paidAmount as num).toDouble();
    final change = (invoice.changeAmount as num).toDouble();
    final balance = (invoice.balance as num).toDouble();
    final discount = (invoice.discountTotal as num).toDouble();
    final tax = (invoice.taxTotal as num).toDouble();

    return AppSectionCard(
      eyebrow: 'Totals',
      child: Column(
        children: [
          _TotalLine(label: 'Subtotal', value: subtotal),
          if (discount > 0) _TotalLine(label: 'Discount', value: -discount),
          if (tax > 0) _TotalLine(label: 'Tax', value: tax),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(height: 1, color: lum.hairline),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total',
                  style: AppTypography.label.copyWith(color: lum.textPrimary),
                ),
              ),
              AppMoneyText(grand, size: 22),
            ],
          ),
          const SizedBox(height: 8),
          _TotalLine(label: 'Paid', value: paid),
          if (change > 0)
            _TotalLine(
              label: 'Change',
              value: change,
              color: lum.successText,
            ),
          if (balance > 0)
            _TotalLine(
              label: 'Balance due',
              value: balance,
              color: lum.warningText,
            ),
        ],
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({required this.label, required this.value, this.color});
  final String label;
  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.footnote.copyWith(color: lum.g500),
            ),
          ),
          AppMoneyText(value, size: 13.5, color: color ?? lum.textPrimary),
        ],
      ),
    );
  }
}

/// Back affordance for the pushed invoice route (it sits outside the nav shell).
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      button: true,
      label: 'Back',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: SizedBox(
          width: 40,
          height: 44,
          child: Icon(LucideIcons.arrowLeft, size: 20, color: lum.g600),
        ),
      ),
    );
  }
}
