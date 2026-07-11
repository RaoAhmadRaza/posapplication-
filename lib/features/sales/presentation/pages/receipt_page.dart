import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/widgets/no_access_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../data/services/receipt_pdf_service.dart';
import '../controllers/invoices_controller.dart';

class ReceiptPage extends ConsumerWidget {
  const ReceiptPage({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PermissionGate(
      module: 'sales',
      action: 'create',
      fallback: const NoAccessScaffold(),
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text('Receipt', style: AppTypography.headline),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: ref.read(invoicesProvider.notifier).loadDetail(invoiceId),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final detail = snapshot.data!;
          final invoiceNumber = detail['invoice_number']?.toString() ?? '';
          final grandTotal = double.tryParse(detail['grand_total']?.toString() ?? '0') ?? 0;
          final paidAmount = double.tryParse(detail['paid_amount']?.toString() ?? '0') ?? 0;
          final changeAmount = double.tryParse(detail['change_amount']?.toString() ?? '0') ?? 0;
          final balance = double.tryParse(detail['balance']?.toString() ?? '0') ?? 0;
          final items = (detail['invoice_items'] as List<dynamic>?) ?? [];

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  Text(invoiceNumber, style: AppTypography.largeTitle.copyWith(color: AppColors.accent)),
                  const SizedBox(height: AppSpacing.xxl),
                  Expanded(
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final item = items[i] as Map<String, dynamic>;
                        final qty = double.tryParse(item['qty']?.toString() ?? '0') ?? 0;
                        final total = double.tryParse(item['line_total']?.toString() ?? '0') ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            children: [
                              Text('${qty.toStringAsFixed(0)}x', style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(child: Text(item['description']?.toString() ?? 'Item', style: AppTypography.subhead)),
                              Text(formatPkr(total), style: AppTypography.headline),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.base),
                    decoration: BoxDecoration(
                      color: AppColors.fieldFill,
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                    ),
                    child: Column(
                      children: [
                        _r('Total', grandTotal, bold: true),
                        _r('Paid', paidAmount),
                        if (changeAmount > 0) _r('Change', changeAmount, color: AppColors.success),
                        if (balance > 0) _r('Balance Due', balance, color: AppColors.warning),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Print / Share Receipt',
                    onPressed: () => _printAndShare(context, detail, invoiceNumber),
                    fullWidth: true,
                    icon: Icons.share,
                    loading: snapshot.connectionState == ConnectionState.waiting,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
  }

  Widget _r(String label, double value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
          Text(
            formatPkr(value),
            style: (bold ? AppTypography.headline : AppTypography.subhead).copyWith(
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printAndShare(BuildContext context, Map<String, dynamic> detail, String number) async {
    final service = ReceiptPdfService();
    final pdfBytes = await service.buildReceipt(detail);
    await Printing.layoutPdf(
      onLayout: (_) => pdfBytes,
      name: 'receipt_$number',
    );
    await service.shareReceipt(pdfBytes, number);
  }
}
