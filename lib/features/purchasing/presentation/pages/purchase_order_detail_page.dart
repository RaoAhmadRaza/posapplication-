import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/design/widgets/app_sheet.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../inventory/domain/entities/product.dart';
import '../../../inventory/presentation/controllers/products_controller.dart';
import '../../../suppliers/domain/entities/supplier.dart';
import '../../../suppliers/presentation/controllers/suppliers_controller.dart';
import '../../domain/entities/purchase_invoice.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/entities/purchase_order_item.dart';
import '../controllers/purchase_invoices_controller.dart';
import '../controllers/purchase_order_detail_provider.dart';
import '../controllers/purchase_orders_controller.dart';
import '../widgets/purchasing_ui.dart';

class PurchaseOrderDetailPage extends ConsumerWidget {
  const PurchaseOrderDetailPage({super.key, required this.poId});
  final String poId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(purchaseOrderDetailProvider(poId));

    return switch (detail) {
      AsyncError() => AppDetailScaffold(
          eyebrow: 'Purchase order',
          title: 'Purchase order',
          child: AppErrorState(
            title: 'Unable to load purchase order',
            body: 'Unable to load suggestions. Check your connection and try again.',
            onRetry: () => ref.invalidate(purchaseOrderDetailProvider(poId)),
          ),
        ),
      AsyncData(:final value) => _Body(po: value.po, items: value.items),
      _ => const AppDetailScaffold(
          eyebrow: 'Purchase order',
          title: 'Purchase order',
          child: Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
    };
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.po, required this.items});
  final PurchaseOrder po;
  final List<PurchaseOrderItem> items;

  void _refresh(WidgetRef ref) =>
      ref.invalidate(purchaseOrderDetailProvider(po.id));

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<dynamic> Function() action,
  ) async {
    final failure = await action();
    if (!context.mounted) return;
    if (failure != null) {
      showAppToast(context, failure.message as String, type: BannerType.error);
      return;
    }
    _refresh(ref);
    showAppToast(context, 'Done.', type: BannerType.success);
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final reason = await showAppSheet<String>(
      context: context,
      builder: (sheetContext) => _CancelSheet(number: po.poNumber),
    );
    if (reason == null || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref
          .read(purchaseOrdersProvider.notifier)
          .cancel(po.id, reason.isEmpty ? null : reason),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(suppliersProvider).value ?? const <Supplier>[];
    final supplier =
        suppliers.where((s) => s.id == po.supplierId).firstOrNull;
    final supplierName =
        supplier?.name ?? 'Supplier ${po.supplierId.substring(0, 6)}';
    final city = supplier?.city?.trim();
    final products = ref.watch(productsProvider).value ?? const <Product>[];
    final names = {for (final p in products) p.id: p.name};

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _orderDetails(context),
        const SizedBox(height: 14),
        _linesCard(context, names),
        const SizedBox(height: 14),
        _GrnsSection(poId: po.id),
        const SizedBox(height: 14),
        _InvoicesSection(poId: po.id),
      ],
    );
    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _totalsCard(context),
        const SizedBox(height: 14),
        ..._actions(context, ref),
        if (po.notes != null && po.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          AppSectionCard(
            eyebrow: 'Notes',
            child: Text(
              po.notes!.trim(),
              style: AppTypography.body.copyWith(color: context.lum.g600),
            ),
          ),
        ],
      ],
    );

    return AppDetailScaffold(
      eyebrow: 'Purchase order',
      title: po.poNumber,
      description: city == null || city.isEmpty
          ? supplierName
          : '$supplierName · $city',
      actions: [
        if (po.status == PurchaseOrderStatus.draft)
          PermissionGate(
            module: 'purchase',
            action: 'update',
            child: AppButton(
              label: 'Edit',
              icon: LucideIcons.pencil,
              variant: AppButtonVariant.tinted,
              size: AppButtonSize.sm,
              onPressed: () => context.push('/purchasing/orders/${po.id}/edit'),
            ),
          ),
      ],
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

  Widget _orderDetails(BuildContext context) {
    final (tone, label) = poStatusPill(po.status);
    return AppSectionCard(
      eyebrow: 'Order details',
      trailing: AppPill(label: label, tone: tone),
      child: Column(
        children: [
          _kv(context, 'Order date', ymd(po.orderDate)),
          _kv(context, 'Expected',
              po.expectedDate == null ? '—' : ymd(po.expectedDate!)),
          _kv(context, 'Currency', '${po.currency} @ ${_rate(po.exchangeRate)}'),
          _kv(context, 'Lines', '${items.length}'),
        ],
      ),
    );
  }

  Widget _linesCard(BuildContext context, Map<String, String> names) {
    return AppSectionCard(
      eyebrow: 'Line items',
      child: items.isEmpty
          ? Text('No line items.',
              style:
                  AppTypography.footnote.copyWith(color: context.lum.g500))
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
    );
  }

  Widget _totalsCard(BuildContext context) {
    return AppSectionCard(
      eyebrow: 'Totals',
      child: Column(
        children: [
          _money(context, 'Subtotal', po.subtotal),
          _money(context, 'Tax', po.taxTotal),
          _money(context, 'Landed cost', po.landedCost),
          Divider(height: 22, color: context.lum.hairline),
          Row(
            children: [
              Expanded(
                child: Text('Grand total',
                    style: AppTypography.headline
                        .copyWith(color: context.lum.textPrimary)),
              ),
              AppMoneyText(po.grandTotal, size: 22, color: context.lum.accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(k,
                style: AppTypography.subhead.copyWith(color: lum.g500)),
          ),
          Text(v,
              style: AppTypography.subhead.copyWith(color: lum.textPrimary)),
        ],
      ),
    );
  }

  Widget _money(BuildContext context, String k, double v) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(k,
                style: AppTypography.subhead.copyWith(color: lum.g500)),
          ),
          AppMoneyText(v, size: 15),
        ],
      ),
    );
  }

  String _rate(double r) =>
      r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toString();

  List<Widget> _actions(BuildContext context, WidgetRef ref) {
    final s = po.status;
    final buttons = <Widget>[];
    void add(Widget w) {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(height: 10));
      buttons.add(w);
    }

    if (s == PurchaseOrderStatus.draft) {
      add(PermissionGate(
        module: 'purchase',
        action: 'create',
        child: AppButton(
          label: 'Submit',
          icon: LucideIcons.send,
          fullWidth: true,
          onPressed: () => _run(context, ref,
              () => ref.read(purchaseOrdersProvider.notifier).submit(po.id)),
        ),
      ));
    }
    if (s == PurchaseOrderStatus.submitted) {
      add(PermissionGate(
        module: 'purchase',
        action: 'approve',
        child: AppButton(
          label: 'Approve',
          icon: LucideIcons.checkCheck,
          fullWidth: true,
          onPressed: () => _run(context, ref,
              () => ref.read(purchaseOrdersProvider.notifier).approve(po.id)),
        ),
      ));
    }
    if (s == PurchaseOrderStatus.approved ||
        s == PurchaseOrderStatus.partiallyReceived) {
      add(PermissionGate(
        module: 'purchase',
        action: 'update',
        child: AppButton(
          label: 'Receive',
          icon: LucideIcons.packageCheck,
          fullWidth: true,
          onPressed: () => context.push('/purchasing/orders/${po.id}/receive'),
        ),
      ));
    }
    if (s == PurchaseOrderStatus.received ||
        s == PurchaseOrderStatus.partiallyReceived) {
      add(PermissionGate(
        module: 'purchase',
        action: 'create',
        child: AppButton(
          label: 'Create invoice',
          icon: LucideIcons.receiptText,
          variant: AppButtonVariant.tinted,
          fullWidth: true,
          onPressed: () => context.push('/purchasing/orders/${po.id}/invoice'),
        ),
      ));
    }
    if (items.any((i) => i.qtyReceived > 0)) {
      add(PermissionGate(
        module: 'purchase',
        action: 'update',
        child: AppButton(
          label: 'Return',
          icon: LucideIcons.undo2,
          variant: AppButtonVariant.tinted,
          fullWidth: true,
          onPressed: () => context.push(
            '/purchasing/returns/create',
            extra: {'poId': po.id},
          ),
        ),
      ));
    }
    const terminal = {
      PurchaseOrderStatus.received,
      PurchaseOrderStatus.invoiced,
      PurchaseOrderStatus.closed,
      PurchaseOrderStatus.cancelled,
    };
    if (!terminal.contains(s)) {
      add(PermissionGate(
        module: 'purchase',
        action: 'delete',
        child: AppButton(
          label: 'Cancel PO',
          icon: LucideIcons.x,
          variant: AppButtonVariant.destructive,
          fullWidth: true,
          onPressed: () => _confirmCancel(context, ref),
        ),
      ));
    }
    if (buttons.isEmpty) return const [];
    return [AppSectionCard(eyebrow: 'Actions', child: Column(children: buttons))];
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.item, required this.name});
  final PurchaseOrderItem item;
  final String name;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final received = item.qtyReceived;
    final showRecv = received > 0;
    final full = received >= item.qtyOrdered;

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
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_n(item.qtyOrdered)} × ${_n(item.unitCost)}'
                  '${item.discountPct > 0 ? ' · -${_n(item.discountPct)}%' : ''}'
                  ' · tax ${_n(item.taxPct)}%',
                  style: AppTypography.caption.copyWith(
                    fontFamily: AppTypography.mono,
                    color: lum.g500,
                  ),
                ),
              ),
              if (showRecv)
                AppPill(
                  label: 'Recv ${_n(received)}/${_n(item.qtyOrdered)}',
                  tone: full ? AppPillTone.success : AppPillTone.warning,
                  showDot: false,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}

class _GrnsSection extends ConsumerWidget {
  const _GrnsSection({required this.poId});
  final String poId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final grns = ref.watch(poGrnsProvider(poId));
    final list = grns.value ?? const [];
    return AppSectionCard(
      eyebrow: 'Goods received (GRN)',
      child: list.isEmpty
          ? Text('No receipts yet.',
              style: AppTypography.footnote.copyWith(color: lum.g500))
          : Column(
              children: [
                for (final g in list)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(LucideIcons.packageCheck,
                            size: 17, color: lum.g500),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(g.grnNumber,
                              style: AppTypography.subhead.copyWith(
                                fontFamily: AppTypography.mono,
                                color: lum.textPrimary,
                              )),
                        ),
                        Text(ymd(g.receivedAt),
                            style: AppTypography.caption
                                .copyWith(color: lum.g500)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _InvoicesSection extends ConsumerWidget {
  const _InvoicesSection({required this.poId});
  final String poId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final invoices =
        ref.watch(purchaseInvoicesProvider).value ?? const <PurchaseInvoice>[];
    final linked = invoices.where((i) => i.poId == poId).toList();
    return AppSectionCard(
      eyebrow: 'Invoices',
      child: linked.isEmpty
          ? Text('No invoices raised yet.',
              style: AppTypography.footnote.copyWith(color: lum.g500))
          : Column(
              children: [
                for (final inv in linked)
                  _InvoiceRow(invoice: inv),
              ],
            ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.invoice});
  final PurchaseInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final (tone, label) = invoiceStatusPill(invoice.status);
    return InkWell(
      onTap: () => context.push('/purchasing/invoices/${invoice.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(LucideIcons.receiptText, size: 17, color: lum.g500),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                invoice.supplierInvoiceNumber?.trim().isNotEmpty == true
                    ? invoice.supplierInvoiceNumber!.trim()
                    : 'Bill',
                style: AppTypography.subhead.copyWith(
                  fontFamily: AppTypography.mono,
                  color: lum.textPrimary,
                ),
              ),
            ),
            AppPill(label: label, tone: tone),
            const SizedBox(width: 10),
            AppMoneyText(invoice.totalAmount, size: 15),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronRight, size: 17, color: lum.g400),
          ],
        ),
      ),
    );
  }
}

/// Cancel-PO confirmation sheet with an optional reason. Pops the reason string
/// (possibly empty) on confirm, or null on back/dismiss.
class _CancelSheet extends StatefulWidget {
  const _CancelSheet({required this.number});
  final String number;

  @override
  State<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<_CancelSheet> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetHeader(title: 'Cancel purchase order?'),
        Text(
          'This will cancel ${widget.number}. Received goods and raised '
          'invoices are kept for the record.',
          style: AppTypography.subhead.copyWith(color: lum.textSecondary),
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _reason,
          label: 'Reason (optional)',
          prefixIcon: LucideIcons.messageSquare,
          hint: 'Why is this being cancelled?',
          maxLines: 2,
        ),
        const SizedBox(height: 20),
        AppButton(
          label: 'Cancel PO',
          variant: AppButtonVariant.destructive,
          fullWidth: true,
          onPressed: () => Navigator.of(context).pop(_reason.text.trim()),
        ),
        const SizedBox(height: 8),
        AppButton(
          label: 'Back',
          variant: AppButtonVariant.plain,
          fullWidth: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
