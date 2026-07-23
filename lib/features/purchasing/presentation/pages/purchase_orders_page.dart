import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_filter_chips.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../suppliers/domain/entities/supplier.dart';
import '../../../suppliers/presentation/controllers/suppliers_controller.dart';
import '../../domain/entities/purchase_order.dart';
import '../controllers/purchase_orders_controller.dart';
import '../widgets/purchasing_ui.dart';

class PurchaseOrdersPage extends ConsumerWidget {
  const PurchaseOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(purchaseOrdersProvider);
    final active = ref.watch(purchaseOrdersProvider.notifier).statusFilter;
    final suppliers = ref.watch(suppliersProvider).value ?? const <Supplier>[];

    // 'All' then every status. Server-side filtering holds only the active
    // status's rows, so chips carry no count badge (no unfiltered set to count).
    const statuses = PurchaseOrderStatus.values;
    final labels = ['All', for (final s in statuses) poStatusPill(s).$2];
    final selected = active == null ? 0 : statuses.indexOf(active) + 1;
    void onSelected(int i) => ref
        .read(purchaseOrdersProvider.notifier)
        .setStatus(i == 0 ? null : statuses[i - 1]);

    final description = switch (state) {
      AsyncData(:final value) =>
        '${value.length} ${value.length == 1 ? 'order' : 'orders'}',
      _ => null,
    };

    return AppDetailScaffold(
      eyebrow: 'Purchasing',
      title: 'Purchase orders',
      description: description,
      actions: [
        PermissionGate(
          module: 'purchase',
          action: 'create',
          child: AppButton(
            label: 'New PO',
            icon: LucideIcons.plus,
            size: AppButtonSize.sm,
            onPressed: () => context.push('/purchasing/orders/create'),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppFilterChips(
            labels: labels,
            selected: selected,
            onSelected: onSelected,
          ),
          const SizedBox(height: 18),
          switch (state) {
            AsyncError() => AppErrorState(
                title: 'Could not load purchase orders',
                body: 'Something went wrong. Check your connection and retry.',
                onRetry: () =>
                    ref.read(purchaseOrdersProvider.notifier).refresh(),
              ),
            AsyncData(:final value) when value.isEmpty => AppEmptyState(
                icon: LucideIcons.clipboardList,
                title: 'No purchase orders',
                body: 'Create a PO to order stock from a supplier.',
                action: PermissionGate(
                  module: 'purchase',
                  action: 'create',
                  child: AppButton(
                    label: 'New PO',
                    icon: LucideIcons.plus,
                    onPressed: () =>
                        context.push('/purchasing/orders/create'),
                  ),
                ),
              ),
            AsyncData(:final value) => Column(
                children: [
                  for (final o in value) ...[
                    _OrderCard(
                      order: o,
                      supplierName: _supplierName(suppliers, o.supplierId),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            _ => const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              ),
          },
        ],
      ),
    );
  }

  static String _supplierName(List<Supplier> suppliers, String id) =>
      suppliers.where((s) => s.id == id).map((s) => s.name).firstOrNull ??
      'Supplier ${id.substring(0, 6)}';
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.supplierName});
  final PurchaseOrder order;
  final String supplierName;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final (tone, label) = poStatusPill(order.status);

    return AppCard(
      onTap: () => context.push('/purchasing/orders/${order.id}'),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.poNumber,
                        style: AppTypography.monoValue.copyWith(
                          fontSize: 15,
                          color: lum.textPrimary,
                        ),
                      ),
                    ),
                    AppPill(label: label, tone: tone),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  supplierName,
                  style: AppTypography.subhead.copyWith(color: lum.textPrimary),
                ),
                const SizedBox(height: 2),
                // 'N lines' omitted — the list query returns PO headers only.
                Text(
                  'Ordered ${ymd(order.orderDate)}',
                  style: AppTypography.footnote.copyWith(color: lum.g500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppMoneyText(order.grandTotal, size: 18),
              const SizedBox(height: 2),
              Text(
                'Grand total',
                style: AppTypography.caption.copyWith(color: lum.g400),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
