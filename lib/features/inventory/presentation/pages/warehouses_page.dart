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
import '../../domain/entities/warehouse.dart';
import '../controllers/warehouses_controller.dart';

class WarehousesPage extends ConsumerWidget {
  const WarehousesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branch = ref.watch(currentBranchProvider);

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
            Text('Warehouses', style: AppTypography.headline),
            if (branch != null)
              Text(
                branch.name,
                style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
              ),
          ],
        ),
        actions: [
          PermissionGate(
            module: 'inventory',
            action: 'create',
            child: IconButton(
              icon: const Icon(Icons.add, color: AppColors.accent),
              onPressed: () => context.push('/inventory/warehouses/create'),
            ),
          ),
        ],
      ),
      body: const _WarehousesBody(),
    );
  }
}

class _WarehousesBody extends ConsumerWidget {
  const _WarehousesBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(warehousesProvider);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppInlineBanner(
                message: 'Could not load warehouses.',
                type: BannerType.error,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Retry',
                onPressed: () =>
                    ref.read(warehousesProvider.notifier).refresh(),
              ),
            ],
          ),
        ),
      ),
      data: (warehouses) {
        if (warehouses.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warehouse, size: 48, color: AppColors.textHint),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No warehouses yet',
                    style: AppTypography.subhead.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Create a warehouse to manage inventory per location.',
                    textAlign: TextAlign.center,
                    style: AppTypography.footnote.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PermissionGate(
                    module: 'inventory',
                    action: 'create',
                    child: AppButton(
                      label: 'Create Warehouse',
                      onPressed: () =>
                          context.push('/inventory/warehouses/create'),
                    ),
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
          itemCount: warehouses.length,
          itemBuilder: (_, i) => Padding(
            padding: EdgeInsets.only(
              bottom: i < warehouses.length - 1 ? AppSpacing.md : 0,
            ),
            child: _WarehouseCard(warehouse: warehouses[i]),
          ),
        );
      },
    );
  }
}

class _WarehouseCard extends ConsumerWidget {
  const _WarehouseCard({required this.warehouse});
  final Warehouse warehouse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: InkWell(
        onTap: () =>
            context.push('/inventory/warehouses/${warehouse.id}'),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(Icons.warehouse, color: AppColors.accent, size: 20),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                warehouse.name,
                                style: AppTypography.headline,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (warehouse.isDefault) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(AppRadius.chip),
                                ),
                                child: Text(
                                  'Default',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          warehouse.code,
                          style: AppTypography.footnote.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ActiveBadge(isActive: warehouse.isActive),
                ],
              ),
              const Divider(color: AppColors.separator, height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PermissionGate(
                    module: 'inventory',
                    action: 'update',
                    child: Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: AppButton(
                        label: 'Set Default',
                        variant: AppButtonVariant.tinted,
                        onPressed: () {
                          ref
                              .read(warehousesProvider.notifier)
                              .setDefault(warehouse.id);
                        },
                      ),
                    ),
                  ),
                  PermissionGate(
                    module: 'inventory',
                    action: 'delete',
                    child: AppButton(
                      label: 'Delete',
                      variant: AppButtonVariant.destructive,
                      onPressed: () =>
                          _confirmDelete(context, ref, warehouse),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Warehouse warehouse,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Warehouse'),
        content: Text(
          'Delete "${warehouse.name}"? This will fail if the warehouse still has stock.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(warehousesProvider.notifier).remove(warehouse.id);
            },
            child: Text('Delete', style: TextStyle(color: AppColors.destructive)),
          ),
        ],
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.textMuted;
    final label = isActive ? 'Active' : 'Inactive';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
