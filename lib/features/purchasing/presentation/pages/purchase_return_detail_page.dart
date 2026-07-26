import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../inventory/domain/entities/product.dart';
import '../../../inventory/presentation/controllers/products_controller.dart';
import '../../../suppliers/domain/entities/supplier.dart';
import '../../../suppliers/presentation/controllers/suppliers_controller.dart';
import '../../domain/entities/purchase_return.dart';
import '../../domain/entities/purchase_return_item.dart';
import '../controllers/purchase_returns_controller.dart';
import '../widgets/purchasing_ui.dart';

class PurchaseReturnDetailPage extends ConsumerWidget {
  const PurchaseReturnDetailPage({super.key, required this.returnId});
  final String returnId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(purchaseReturnDetailProvider(returnId));

    return switch (detail) {
      AsyncError() => AppDetailScaffold(
          eyebrow: 'Purchase return',
          title: 'Purchase return',
          child: AppErrorState(
            title: 'Unable to load purchase return',
            body: 'Unable to load suggestions. Check your connection and try again.',
            onRetry: () =>
                ref.invalidate(purchaseReturnDetailProvider(returnId)),
          ),
        ),
      AsyncData(:final value) => _Body(ret: value.ret, items: value.items),
      _ => const AppDetailScaffold(
          eyebrow: 'Purchase return',
          title: 'Purchase return',
          child: Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
    };
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.ret, required this.items});
  final PurchaseReturn ret;
  final List<PurchaseReturnItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final suppliers = ref.watch(suppliersProvider).value ?? const <Supplier>[];
    final supplierName = suppliers
            .where((s) => s.id == ret.supplierId)
            .map((s) => s.name)
            .firstOrNull ??
        'Supplier ${ret.supplierId.substring(0, 6)}';
    final products = ref.watch(productsProvider).value ?? const <Product>[];
    final names = {for (final p in products) p.id: p.name};
    final (tone, label) = returnStatusPill(ret.status);
    final reason = ret.reason?.trim();
    final notes = ret.notes?.trim();

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionCard(
          eyebrow: 'Return details',
          trailing: AppPill(label: label, tone: tone),
          child: Column(
            children: [
              _kv(context, 'Date', ymd(ret.returnDate)),
              _kv(context, 'Reason',
                  reason == null || reason.isEmpty ? '—' : reason),
              if (notes != null && notes.isNotEmpty)
                _kv(context, 'Notes', notes),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppSectionCard(
          eyebrow: 'Returned items',
          child: items.isEmpty
              ? Text('No line items.',
                  style: AppTypography.footnote.copyWith(color: lum.g500))
              : Column(
                  children: [
                    for (final it in items)
                      _LineRow(
                        item: it,
                        name: names[it.productId] ??
                            'Item ${it.productId.substring(0, 6)}',
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        AppSectionCard(
          eyebrow: 'Source',
          child: InkWell(
            onTap: () => context.push('/purchasing/orders/${ret.poId}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(LucideIcons.clipboardList, size: 18, color: lum.g500),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('View purchase order',
                        style: AppTypography.subhead
                            .copyWith(color: lum.textPrimary)),
                  ),
                  Icon(LucideIcons.chevronRight, size: 18, color: lum.g400),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    final right = AppSectionCard(
      eyebrow: 'Total',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Debit note',
                    style: AppTypography.headline
                        .copyWith(color: lum.textPrimary)),
              ),
              AppMoneyText(ret.totalAmount, size: 22, color: lum.dangerText),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'A return is final once created. No further changes can be made.',
            style: AppTypography.caption.copyWith(color: lum.g500),
          ),
        ],
      ),
    );

    return AppDetailScaffold(
      eyebrow: 'Purchase return',
      title: ret.returnNumber,
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

  Widget _kv(BuildContext context, String k, String v) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(k,
                style: AppTypography.subhead.copyWith(color: lum.g500)),
          ),
          Expanded(
            child: Text(v,
                style: AppTypography.subhead.copyWith(color: lum.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.item, required this.name});
  final PurchaseReturnItem item;
  final String name;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final imeis = item.imeiIds ?? const <String>[];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    style: AppTypography.subhead
                        .copyWith(color: lum.textPrimary)),
              ),
              const SizedBox(width: 10),
              AppMoneyText(item.lineTotal, size: 15),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${_n(item.qtyReturned)} × ${_n(item.unitCost)} · '
            'tax ${_n(item.taxPct)}%',
            style: AppTypography.caption.copyWith(
              fontFamily: AppTypography.mono,
              color: lum.g500,
            ),
          ),
          if (imeis.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final imei in imeis.take(3))
                  AppPill(
                    label: imei,
                    tone: AppPillTone.transit,
                    showDot: false,
                  ),
                if (imeis.length > 3)
                  AppPill(
                    label: '+${imeis.length - 3}',
                    tone: AppPillTone.neutral,
                    showDot: false,
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
