import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_list_skeleton.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/stock_adjustment.dart';
import '../../domain/entities/warehouse.dart';
import '../controllers/adjustments_controller.dart';
import '../controllers/products_controller.dart';
import '../controllers/warehouses_controller.dart';
import '../widgets/inventory_ui.dart';

class AdjustmentsPage extends ConsumerStatefulWidget {
  const AdjustmentsPage({super.key});

  @override
  ConsumerState<AdjustmentsPage> createState() => _AdjustmentsPageState();
}

class _AdjustmentsPageState extends ConsumerState<AdjustmentsPage> {
  bool _pendingOnly = false;

  @override
  Widget build(BuildContext context) {
    // Keep the branch watch so the list re-scopes when the active branch changes.
    ref.watch(currentBranchProvider);
    final state = ref.watch(adjustmentsProvider);

    return AppDetailScaffold(
      eyebrow: 'Inventory',
      title: 'Adjustments',
      actions: [
        PermissionGate(
          module: 'inventory',
          action: 'update',
          child: AppButton(
            label: 'New adjustment',
            icon: LucideIcons.plus,
            size: AppButtonSize.sm,
            onPressed: () => context.push('/inventory/adjustments/create'),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _PendingToggle(
              value: _pendingOnly,
              onChanged: (v) => setState(() => _pendingOnly = v),
            ),
          ),
          const SizedBox(height: 14),
          _buildBody(state),
        ],
      ),
    );
  }

  Widget _buildBody(AsyncValue<List<StockAdjustment>> state) {
    return state.when(
      loading: () => const AppListSkeleton(),
      error: (e, _) => AppErrorState(
        title: "We couldn't load adjustments",
        body: 'Please try again in a moment.',
        onRetry: () => ref.invalidate(adjustmentsProvider),
      ),
      data: (adjustments) {
        final filtered = _pendingOnly
            ? adjustments
                .where((a) => a.requiresApproval && !a.posted)
                .toList()
            : adjustments;

        if (filtered.isEmpty) {
          return AppEmptyState(
            icon: LucideIcons.slidersHorizontal,
            title: _pendingOnly
                ? 'No pending adjustments'
                : 'No adjustments yet',
            body: _pendingOnly
                ? 'All adjustments have been processed.'
                : 'Create a stock adjustment to get started.',
            action: _pendingOnly
                ? null
                : PermissionGate(
                    module: 'inventory',
                    action: 'update',
                    child: AppButton(
                      label: 'New adjustment',
                      icon: LucideIcons.plus,
                      onPressed: () =>
                          context.push('/inventory/adjustments/create'),
                    ),
                  ),
          );
        }

        return Column(
          children: [
            for (final a in filtered) ...[
              _AdjustmentCard(adjustment: a),
              if (a != filtered.last) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _PendingToggle extends StatelessWidget {
  const _PendingToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      button: true,
      toggled: value,
      label: 'Pending only',
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: ClayContainer(
          variant: value ? ClayVariant.pressed : ClayVariant.soft,
          color: value ? lum.warningSoft : lum.surface,
          borderRadius: AppRadius.pill,
          isDark: lum.isDark,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.hourglass,
                size: 15,
                color: value ? lum.warningText : lum.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Pending only',
                style: AppTypography.subhead.copyWith(
                  color: value ? lum.warningText : lum.textSecondary,
                  fontWeight: value ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdjustmentCard extends ConsumerWidget {
  const _AdjustmentCard({required this.adjustment});
  final StockAdjustment adjustment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final products = ref.watch(productsProvider).value ?? <Product>[];
    final warehouses = ref.watch(warehousesProvider).value ?? <Warehouse>[];

    final product =
        products.where((p) => p.id == adjustment.productId).firstOrNull;
    final warehouse = adjustment.warehouseId == null
        ? null
        : warehouses.where((w) => w.id == adjustment.warehouseId).firstOrNull;

    final isNegative = adjustment.adjQty < 0;
    final signTint = isNegative ? lum.dangerSoft : lum.successSoft;
    final signIcon = isNegative ? lum.dangerText : lum.successText;
    final qtyColor = isNegative ? lum.dangerText : lum.successText;

    final subtitle = [
      adjustmentReasonLabel(adjustment.reasonCode),
      if (warehouse != null) warehouse.name,
      ymd(adjustment.createdAt),
    ].join(' · ');

    final signed = isNegative
        ? '-${qtyLabel(adjustment.adjQty.abs())}'
        : '+${qtyLabel(adjustment.adjQty)}';

    final (pillTone, pillLabel) =
        adjustmentStatusPill(posted: adjustment.posted);

    final showApprove = adjustment.requiresApproval &&
        !adjustment.posted &&
        adjustment.approvedBy == null;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClayContainer(
                variant: ClayVariant.soft,
                color: signTint,
                borderRadius: AppRadius.sm,
                isDark: lum.isDark,
                width: 42,
                height: 42,
                child: Center(
                  child: Icon(
                    LucideIcons.slidersHorizontal,
                    size: 19,
                    color: signIcon,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product?.name ?? 'Product',
                      style: AppTypography.headline
                          .copyWith(color: lum.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.footnote.copyWith(color: lum.g500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    signed,
                    style: AppTypography.headline.copyWith(
                      color: qtyColor,
                      fontFamily: AppTypography.mono,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AppPill(label: pillLabel, tone: pillTone),
                ],
              ),
            ],
          ),
          if (showApprove) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: PermissionGate(
                module: 'inventory',
                action: 'approve',
                child: AppButton(
                  label: 'Approve',
                  variant: AppButtonVariant.tinted,
                  size: AppButtonSize.sm,
                  onPressed: () => ref
                      .read(adjustmentsProvider.notifier)
                      .approve(adjustment.id),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
