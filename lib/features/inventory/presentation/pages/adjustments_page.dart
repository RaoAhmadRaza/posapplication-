import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/stock_adjustment.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/adjustment_reason.dart';
import '../controllers/adjustments_controller.dart';
import '../controllers/products_controller.dart';

class AdjustmentsPage extends ConsumerStatefulWidget {
  const AdjustmentsPage({super.key});

  @override
  ConsumerState<AdjustmentsPage> createState() => _AdjustmentsPageState();
}

class _AdjustmentsPageState extends ConsumerState<AdjustmentsPage> {
  bool _pendingOnly = false;

  @override
  Widget build(BuildContext context) {
    final branch = ref.watch(currentBranchProvider);
    final state = ref.watch(adjustmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Adjustments', style: AppTypography.headline),
            if (branch != null)
              Text(branch.name, style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
          ],
        ),
        actions: [
          PermissionGate(
            module: 'inventory',
            action: 'update',
            child: IconButton(
              icon: const Icon(Icons.add, color: AppColors.accent),
              onPressed: () => context.push('/inventory/adjustments/create'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    _PendingToggle(
                      value: _pendingOnly,
                      onChanged: (v) => setState(() => _pendingOnly = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(child: _buildBody(state)),
        ],
      ),
    );
  }

  Widget _buildBody(AsyncValue<List<StockAdjustment>> state) {
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppInlineBanner(message: 'Could not load adjustments.', type: BannerType.error),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Retry',
                onPressed: () => ref.invalidate(adjustmentsProvider),
              ),
            ],
          ),
        ),
      ),
      data: (adjustments) {
        var filtered = _pendingOnly
            ? adjustments.where((a) => !a.posted && a.requiresApproval).toList()
            : adjustments;

        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _pendingOnly ? Icons.checklist : Icons.tune,
                    size: 48,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _pendingOnly ? 'No pending adjustments' : 'No adjustments yet',
                    style: AppTypography.subhead.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _pendingOnly ? 'All adjustments have been processed.' : 'Create a stock adjustment to get started.',
                    textAlign: TextAlign.center,
                    style: AppTypography.footnote.copyWith(color: AppColors.textHint),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
            vertical: AppSpacing.md,
          ),
          itemCount: filtered.length,
          itemBuilder: (_, i) => Padding(
            padding: EdgeInsets.only(bottom: i < filtered.length - 1 ? AppSpacing.md : 0),
            child: _AdjustmentCard(adjustment: filtered[i]),
          ),
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
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: value ? AppColors.warning.withValues(alpha: 0.12) : AppColors.fieldFill,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: value ? Border.all(color: AppColors.warning, width: 1) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_empty, size: 16, color: value ? AppColors.warning : AppColors.textMuted),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Pending',
              style: AppTypography.footnote.copyWith(
                color: value ? AppColors.warning : AppColors.textMuted,
                fontWeight: value ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
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
    final products = ref.watch(productsProvider).value ?? <Product>[];
    final product = products.where((p) => p.id == adjustment.productId).firstOrNull;

    final isPositive = adjustment.adjQty > 0;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      (product?.name ?? '?').isNotEmpty
                          ? (product?.name ?? '?')[0].toUpperCase()
                          : '?',
                      style: AppTypography.headline.copyWith(color: AppColors.accent),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product?.name ?? 'Product',
                        style: AppTypography.headline,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'SKU: ${product?.sku ?? '...'}',
                            style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _ReasonChip(reason: adjustment.reasonCode),
                        ],
                      ),
                    ],
                  ),
                ),
                _StatusBadge(adjustment: adjustment),
              ],
            ),
            const Divider(color: AppColors.separator, height: AppSpacing.xl),
            Row(
              children: [
                Text(
                  isPositive ? '+${adjustment.adjQty}' : '${adjustment.adjQty}',
                  style: AppTypography.headline.copyWith(
                    color: isPositive ? AppColors.success : AppColors.destructive,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '× ${adjustment.costPerUnit.toStringAsFixed(2)}',
                  style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
                ),
                const Spacer(),
                if (adjustment.requiresApproval && !adjustment.posted)
                  PermissionGate(
                    module: 'inventory',
                    action: 'approve',
                    child: AppButton(
                      label: 'Approve',
                      variant: AppButtonVariant.tinted,
                      onPressed: () {
                        ref.read(adjustmentsProvider.notifier).approve(adjustment.id);
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.reason});
  final AdjustmentReason reason;

  @override
  Widget build(BuildContext context) {
    final label = reason.dbValue.replaceAll('_', ' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.textMuted.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.adjustment});
  final StockAdjustment adjustment;

  @override
  Widget build(BuildContext context) {
    if (adjustment.posted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Text(
          'Posted',
          style: AppTypography.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.w600),
        ),
      );
    }
    if (adjustment.requiresApproval) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Text(
          'Pending',
          style: AppTypography.caption.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
