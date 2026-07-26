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
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/design/widgets/lumina_brand.dart';
import '../../../../core/widgets/no_access_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../data/services/receipt_pdf_service.dart';
import '../controllers/invoices_controller.dart';
import '../widgets/sales_rise.dart';
import '../widgets/sales_scaffold.dart';

class ReceiptPage extends ConsumerWidget {
  const ReceiptPage({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PermissionGate(
      module: 'sales',
      action: 'create',
      fallback: const NoAccessScaffold(),
      child: SalesScaffold(
        title: 'Receipt',
        maxContentWidth: 420,
        padding: const EdgeInsets.all(24),
        child: FutureBuilder<Map<String, dynamic>?>(
          future: ref.read(invoicesProvider.notifier).loadDetail(invoiceId),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final detail = snapshot.data!;
            final invoiceNumber = detail['invoice_number']?.toString() ?? '';

            return SalesRise(
              duration: const Duration(milliseconds: 350),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ReceiptSlip(detail: detail),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Print & share',
                            onPressed: () =>
                                _printAndShare(context, detail, invoiceNumber),
                            icon: LucideIcons.printer,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppButton(
                            label: 'Done',
                            onPressed: () => Navigator.of(context).maybePop(),
                            variant: AppButtonVariant.plain,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _printAndShare(
    BuildContext context,
    Map<String, dynamic> detail,
    String number,
  ) async {
    try {
      final service = ReceiptPdfService();
      final pdfBytes = await service.buildReceipt(detail);
      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'receipt_$number',
      );
      final shared = await service.shareReceipt(pdfBytes, number);
      if (!shared && context.mounted) {
        showAppToast(
          context,
          'Printed. Unable to share the PDF on this device.',
          type: BannerType.warning,
        );
      }
    } catch (e) {
      // Without this the whole flow fails silently and the button reads as dead.
      if (context.mounted) {
        showAppToast(context, 'Print failed: $e', type: BannerType.error);
      }
    }
  }
}

/// The printed slip, rendered on screen: brand header, items, totals and the
/// shop's footer note, split by dashed rules.
class _ReceiptSlip extends ConsumerWidget {
  const _ReceiptSlip({required this.detail});

  final Map<String, dynamic> detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final branch = ref.watch(currentBranchProvider);
    final invoiceNumber = detail['invoice_number']?.toString() ?? '';
    final grandTotal =
        double.tryParse(detail['grand_total']?.toString() ?? '0') ?? 0;
    final paidAmount =
        double.tryParse(detail['paid_amount']?.toString() ?? '0') ?? 0;
    final changeAmount =
        double.tryParse(detail['change_amount']?.toString() ?? '0') ?? 0;
    final balance = double.tryParse(detail['balance']?.toString() ?? '0') ?? 0;
    final items = (detail['invoice_items'] as List<dynamic>?) ?? [];
    final payments = (detail['payments'] as List<dynamic>?) ?? [];
    final createdAt = DateTime.tryParse(detail['created_at']?.toString() ?? '');

    return ClayContainer(
      variant: ClayVariant.raised,
      color: lum.surface,
      borderRadius: AppRadius.lg,
      isDark: lum.isDark,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              LuminaGlyph(size: 24),
              SizedBox(width: 8),
              LuminaWordmark(size: 18),
            ],
          ),
          const SizedBox(height: 10),
          if (branch != null)
            Text(
              branch.name,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: lum.g500),
            ),
          const SizedBox(height: 2),
          Text(
            [
              invoiceNumber,
              if (createdAt != null) _stamp(createdAt),
            ].join(' · '),
            textAlign: TextAlign.center,
            style: AppTypography.monoValue.copyWith(
              fontSize: 12,
              color: lum.g500,
            ),
          ),
          const _DashedRule(),
          for (final raw in items) _ItemLine(item: raw as Map<String, dynamic>),
          const _DashedRule(),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total',
                  style: AppTypography.label.copyWith(color: lum.textPrimary),
                ),
              ),
              Text(
                formatPkr(grandTotal),
                style: AppTypography.monoValue.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: lum.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final raw in payments)
            _MetaLine(
              label: _methodLabel(
                (raw as Map<String, dynamic>)['method']?.toString(),
              ),
              value: double.tryParse(raw['amount']?.toString() ?? '0') ?? 0,
            ),
          if (changeAmount > 0)
            _MetaLine(label: 'Change', value: changeAmount),
          if (balance > 0) _MetaLine(label: 'Balance due', value: balance),
          if (payments.isEmpty && changeAmount == 0 && balance == 0)
            _MetaLine(label: 'Paid', value: paidAmount),
          const _DashedRule(),
          Text(
            'Thank you for your business.',
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              height: 1.6,
              color: lum.g500,
            ),
          ),
        ],
      ),
    );
  }

  static String _stamp(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  static String _methodLabel(String? raw) {
    if (raw == null || raw.isEmpty) return 'Payment';
    final words = raw.toLowerCase().split('_');
    return words
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

class _ItemLine extends StatelessWidget {
  const _ItemLine({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final qty = double.tryParse(item['qty']?.toString() ?? '0') ?? 0;
    final unit = double.tryParse(item['unit_price']?.toString() ?? '0') ?? 0;
    final total = double.tryParse(item['line_total']?.toString() ?? '0') ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  // invoice_items carries no product name or SKU — only the
                  // description written at sale time.
                  item['description']?.toString().trim().isNotEmpty == true
                      ? item['description'].toString()
                      : 'Item',
                  style: AppTypography.footnote.copyWith(
                    fontSize: 13,
                    color: lum.textPrimary,
                  ),
                ),
                Text(
                  '${qty.toStringAsFixed(0)} × ${formatPkr(unit)}',
                  style: AppTypography.monoValue.copyWith(
                    fontSize: 11,
                    color: lum.g500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatPkr(total),
            style: AppTypography.monoValue.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: lum.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.caption.copyWith(color: lum.g500),
            ),
          ),
          Text(
            formatPkr(value),
            style: AppTypography.monoValue.copyWith(
              fontSize: 12.5,
              color: lum.g600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 1.5px dashed rule separating receipt sections.
class _DashedRule extends StatelessWidget {
  const _DashedRule();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: CustomPaint(
        size: const Size(double.infinity, 1.5),
        painter: _DashedPainter(color: context.lum.g200),
      ),
    );
  }
}

class _DashedPainter extends CustomPainter {
  const _DashedPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const dash = 4.0;
    const gap = 4.0;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + dash).clamp(0, size.width), size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) => old.color != color;
}
