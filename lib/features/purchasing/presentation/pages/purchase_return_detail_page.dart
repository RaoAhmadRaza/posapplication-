import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../suppliers/domain/entities/supplier.dart';
import '../../../suppliers/presentation/controllers/suppliers_controller.dart';
import '../../domain/entities/purchase_return.dart';
import '../../domain/entities/purchase_return_item.dart';
import '../controllers/purchase_returns_controller.dart';
import 'purchase_orders_page.dart' show fmtPoDate;
import 'purchase_returns_page.dart'
    show returnStatusColor, returnStatusLabels;

class PurchaseReturnDetailPage extends ConsumerWidget {
  const PurchaseReturnDetailPage({super.key, required this.returnId});
  final String returnId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(purchaseReturnDetailProvider(returnId));

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
        title: Text('Purchase Return', style: AppTypography.headline),
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding),
            child: AppInlineBanner(
                message: 'Could not load purchase return.',
                type: BannerType.error),
          ),
        ),
        data: (d) => _Body(ret: d.ret, items: d.items),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.ret, required this.items});
  final PurchaseReturn ret;
  final List<PurchaseReturnItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(suppliersProvider).value ?? const <Supplier>[];
    final supplierName = suppliers
            .where((s) => s.id == ret.supplierId)
            .map((s) => s.name)
            .firstOrNull ??
        'Supplier ${ret.supplierId.substring(0, 6)}';

    return ListView(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
      children: [
        _HeaderCard(ret: ret, supplierName: supplierName),
        const SizedBox(height: AppSpacing.md),
        _LinesCard(items: items),
        const SizedBox(height: AppSpacing.md),
        InkWell(
          onTap: () => context.push('/purchasing/orders/${ret.poId}'),
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: AppCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long,
                      size: 18, color: AppColors.textMuted),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                      child: Text('View purchase order',
                          style: AppTypography.footnote)),
                  const Icon(Icons.chevron_right,
                      color: AppColors.separator),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.ret, required this.supplierName});
  final PurchaseReturn ret;
  final String supplierName;

  @override
  Widget build(BuildContext context) {
    final color = returnStatusColor(ret.status);
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child:
                        Text(ret.returnNumber, style: AppTypography.largeTitle)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Text(returnStatusLabels[ret.status]!,
                      style: AppTypography.caption.copyWith(
                          color: color, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _line(Icons.local_shipping, supplierName),
            _line(Icons.calendar_today, 'Returned ${fmtPoDate(ret.returnDate)}'),
            if (ret.reason != null && ret.reason!.isNotEmpty)
              _line(Icons.info_outline, ret.reason!),
            const Divider(color: AppColors.separator, height: AppSpacing.xl),
            _amount('Subtotal', ret.subtotal),
            _amount('Tax', ret.taxTotal),
            const SizedBox(height: AppSpacing.xs),
            _amount('Total Returned', ret.totalAmount, emphasize: true),
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

  Widget _amount(String label, double value, {bool emphasize = false}) {
    final style = emphasize
        ? AppTypography.headline
        : AppTypography.footnote.copyWith(color: AppColors.textMuted);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(formatPkr(value), style: style),
        ],
      ),
    );
  }
}

class _LinesCard extends StatelessWidget {
  const _LinesCard({required this.items});
  final List<PurchaseReturnItem> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RETURNED ITEMS',
                style: AppTypography.footnote.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            if (items.isEmpty)
              Text('No line items.',
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.textHint))
            else
              for (final it in items) _LineRow(item: it),
          ],
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.item});
  final PurchaseReturnItem item;

  @override
  Widget build(BuildContext context) {
    final imeis = item.imeiIds ?? const <String>[];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Item ${item.productId.substring(0, 6)}',
                    style: AppTypography.subhead),
              ),
              Text(formatPkr(item.lineTotal),
                  style: AppTypography.subhead
                      .copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Returned ${_n(item.qtyReturned)} · '
            'Cost ${formatPkr(item.unitCost)}',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
          if (imeis.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: 4,
              children: [
                for (final imei in imeis)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.smartphone,
                          size: 13, color: AppColors.textHint),
                      const SizedBox(width: 2),
                      Text(imei,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textHint)),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}
