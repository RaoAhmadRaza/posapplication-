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
import '../../../suppliers/domain/entities/supplier.dart';
import '../../../suppliers/presentation/controllers/suppliers_controller.dart';
import '../../domain/entities/purchase_invoice.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/entities/purchase_order_item.dart';
import '../controllers/purchase_invoices_controller.dart';
import '../controllers/purchase_order_detail_provider.dart';
import '../controllers/purchase_orders_controller.dart';
import 'purchase_orders_page.dart';

class PurchaseOrderDetailPage extends ConsumerWidget {
  const PurchaseOrderDetailPage({super.key, required this.poId});
  final String poId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(purchaseOrderDetailProvider(poId));

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
        title: Text('Purchase Order', style: AppTypography.headline),
        actions: [
          detail.maybeWhen(
            data: (d) => d.po.status == PurchaseOrderStatus.draft
                ? PermissionGate(
                    module: 'purchase',
                    action: 'update',
                    child: IconButton(
                      icon: const Icon(Icons.edit,
                          color: AppColors.accent, size: 20),
                      onPressed: () =>
                          context.push('/purchasing/orders/$poId/edit'),
                    ),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding),
            child: AppInlineBanner(
                message: 'Could not load purchase order.',
                type: BannerType.error),
          ),
        ),
        data: (d) => _Body(po: d.po, items: d.items),
      ),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message as String)));
      return;
    }
    _refresh(ref);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Done.')));
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel PO'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Back')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Cancel PO',
                style: TextStyle(color: AppColors.destructive)),
          ),
        ],
      ),
    );
    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (confirmed != true || !context.mounted) return;
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
    return ListView(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
      children: [
        _HeaderCard(po: po),
        const SizedBox(height: AppSpacing.md),
        _LinesCard(items: items),
        const SizedBox(height: AppSpacing.md),
        _GrnsSection(poId: po.id),
        const SizedBox(height: AppSpacing.md),
        _InvoicesSection(poId: po.id),
        const SizedBox(height: AppSpacing.xl),
        ..._actions(context, ref),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  List<Widget> _actions(BuildContext context, WidgetRef ref) {
    final s = po.status;
    final buttons = <Widget>[];

    void add(Widget w) {
      if (buttons.isNotEmpty) {
        buttons.add(const SizedBox(height: AppSpacing.md));
      }
      buttons.add(w);
    }

    if (s == PurchaseOrderStatus.draft) {
      add(PermissionGate(
        module: 'purchase',
        action: 'create',
        child: AppButton(
          label: 'Submit',
          icon: Icons.send,
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
          icon: Icons.check_circle,
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
          icon: Icons.inventory,
          fullWidth: true,
          onPressed: () =>
              context.push('/purchasing/orders/${po.id}/receive'),
        ),
      ));
    }
    if (s == PurchaseOrderStatus.received ||
        s == PurchaseOrderStatus.partiallyReceived) {
      add(PermissionGate(
        module: 'purchase',
        action: 'create',
        child: AppButton(
          label: 'Create Invoice',
          icon: Icons.request_quote,
          variant: AppButtonVariant.tinted,
          fullWidth: true,
          onPressed: () =>
              context.push('/purchasing/orders/${po.id}/invoice'),
        ),
      ));
    }
    if (items.any((i) => i.qtyReceived > 0)) {
      add(PermissionGate(
        module: 'purchase',
        action: 'update',
        child: AppButton(
          label: 'Return',
          icon: Icons.assignment_return,
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
          icon: Icons.cancel_outlined,
          variant: AppButtonVariant.destructive,
          fullWidth: true,
          onPressed: () => _confirmCancel(context, ref),
        ),
      ));
    }
    return buttons;
  }
}

class _HeaderCard extends ConsumerWidget {
  const _HeaderCard({required this.po});
  final PurchaseOrder po;

  String _fmtDate(DateTime d) => fmtPoDate(d);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers =
        ref.watch(suppliersProvider).value ?? const <Supplier>[];
    final supplierName = suppliers
        .where((s) => s.id == po.supplierId)
        .map((s) => s.name)
        .firstOrNull;
    final color = poStatusColor(po.status);

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
                        Text(po.poNumber, style: AppTypography.largeTitle)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Text(poStatusLabels[po.status]!,
                      style: AppTypography.caption.copyWith(
                          color: color, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _line(Icons.local_shipping,
                supplierName ?? 'Supplier ${po.supplierId.substring(0, 6)}'),
            _line(Icons.calendar_today, 'Ordered ${_fmtDate(po.orderDate)}'),
            if (po.expectedDate != null)
              _line(Icons.event, 'Expected ${_fmtDate(po.expectedDate!)}'),
            const Divider(color: AppColors.separator, height: AppSpacing.xl),
            _amount('Subtotal', po.subtotal),
            _amount('Tax', po.taxTotal),
            _amount('Landed Cost', po.landedCost),
            const SizedBox(height: AppSpacing.xs),
            _amount('Grand Total', po.grandTotal, emphasize: true),
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
  final List<PurchaseOrderItem> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ITEMS',
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
  final PurchaseOrderItem item;

  @override
  Widget build(BuildContext context) {
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
            'Recv ${_n(item.qtyReceived)}/${_n(item.qtyOrdered)} · '
            'Cost ${formatPkr(item.unitCost)} · '
            'Landed ${formatPkr(item.landedCostAllocated)}',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  String _n(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2);
}

class _GrnsSection extends ConsumerWidget {
  const _GrnsSection({required this.poId});
  final String poId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grns = ref.watch(poGrnsProvider(poId));
    return grns.maybeWhen(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GOODS RECEIPTS',
                    style: AppTypography.footnote.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.sm),
                for (final g in list)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory,
                            size: 16, color: AppColors.textMuted),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                            child: Text(g.grnNumber,
                                style: AppTypography.footnote)),
                        Text(fmtPoDate(g.receivedAt),
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _InvoicesSection extends ConsumerWidget {
  const _InvoicesSection({required this.poId});
  final String poId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(purchaseInvoicesProvider).value ??
        const <PurchaseInvoice>[];
    final linked = invoices.where((i) => i.poId == poId).toList();
    if (linked.isEmpty) return const SizedBox.shrink();
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('INVOICES',
                style: AppTypography.footnote.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            for (final inv in linked)
              InkWell(
                onTap: () => context.push('/purchasing/invoices/${inv.id}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.request_quote,
                          size: 16, color: AppColors.textMuted),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                            inv.supplierInvoiceNumber ?? 'Invoice',
                            style: AppTypography.footnote),
                      ),
                      Text('Bal ${formatPkr(inv.balance)}',
                          style: AppTypography.caption.copyWith(
                              color: inv.balance > 0
                                  ? AppColors.destructive
                                  : AppColors.textMuted)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
