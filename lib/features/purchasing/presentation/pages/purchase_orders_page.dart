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
import '../../domain/entities/purchase_order.dart';
import '../controllers/purchase_orders_controller.dart';

const poStatusLabels = {
  PurchaseOrderStatus.draft: 'Draft',
  PurchaseOrderStatus.submitted: 'Submitted',
  PurchaseOrderStatus.approved: 'Approved',
  PurchaseOrderStatus.partiallyReceived: 'Receiving',
  PurchaseOrderStatus.received: 'Received',
  PurchaseOrderStatus.invoiced: 'Invoiced',
  PurchaseOrderStatus.closed: 'Closed',
  PurchaseOrderStatus.cancelled: 'Cancelled',
};

Color poStatusColor(PurchaseOrderStatus status) {
  return switch (status) {
    PurchaseOrderStatus.draft => AppColors.textMuted,
    PurchaseOrderStatus.cancelled => AppColors.destructive,
    PurchaseOrderStatus.approved ||
    PurchaseOrderStatus.received ||
    PurchaseOrderStatus.closed =>
      AppColors.success,
    _ => AppColors.accent,
  };
}

String fmtPoDate(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

class PurchaseOrdersPage extends ConsumerWidget {
  const PurchaseOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(purchaseOrdersProvider);
    final activeStatus = ref.watch(purchaseOrdersProvider.notifier).statusFilter;

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
        title: Text('Purchase Orders', style: AppTypography.headline),
      ),
      floatingActionButton: PermissionGate(
        module: 'purchase',
        action: 'create',
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.accent,
          onPressed: () => context.push('/purchasing/orders/create'),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('New PO', style: TextStyle(color: Colors.white)),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _StatusFilterBar(
              active: activeStatus,
              onSelected: (s) =>
                  ref.read(purchaseOrdersProvider.notifier).setStatus(s),
            ),
            Expanded(
              child: state.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorState(
                  onRetry: () =>
                      ref.read(purchaseOrdersProvider.notifier).refresh(),
                ),
                data: (orders) => orders.isEmpty
                    ? const _EmptyState()
                    : _OrdersList(orders: orders),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({required this.active, required this.onSelected});
  final PurchaseOrderStatus? active;
  final ValueChanged<PurchaseOrderStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding, vertical: AppSpacing.xs),
        children: [
          _chip('All', active == null, () => onSelected(null)),
          for (final s in PurchaseOrderStatus.values) ...[
            const SizedBox(width: AppSpacing.sm),
            _chip(poStatusLabels[s]!, active == s, () => onSelected(s)),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent
              : AppColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.footnote.copyWith(
            color: selected ? Colors.white : AppColors.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({required this.orders});
  final List<PurchaseOrder> orders;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
      itemCount: orders.length,
      itemBuilder: (_, i) {
        final o = orders[i];
        return Padding(
          padding: EdgeInsets.only(
              bottom: i < orders.length - 1 ? AppSpacing.md : 0),
          child: _OrderCard(order: o),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final PurchaseOrder order;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: InkWell(
        onTap: () => context.push('/purchasing/orders/${order.id}'),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.poNumber, style: AppTypography.headline),
                    const SizedBox(height: 2),
                    Text(fmtPoDate(order.orderDate),
                        style: AppTypography.footnote
                            .copyWith(color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    Text(formatPkr(order.grandTotal),
                        style: AppTypography.subhead.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              _StatusBadge(status: order.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final PurchaseOrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = poStatusColor(status);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        poStatusLabels[status]!,
        style: AppTypography.caption
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
            Text('No purchase orders yet',
                style: AppTypography.subhead
                    .copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.xs),
            Text('Create a PO to order stock from a supplier.',
                textAlign: TextAlign.center,
                style: AppTypography.footnote
                    .copyWith(color: AppColors.textHint)),
            const SizedBox(height: AppSpacing.xl),
            PermissionGate(
              module: 'purchase',
              action: 'create',
              child: AppButton(
                label: 'New PO',
                onPressed: () => context.push('/purchasing/orders/create'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppInlineBanner(
                message: 'Could not load purchase orders.',
                type: BannerType.error),
            const SizedBox(height: AppSpacing.md),
            AppButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
